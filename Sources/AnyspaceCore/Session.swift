import CoreAudio
import Foundation

/// Junta tudo: cena, taps por aplicativo, motor 3D. Use sempre da thread principal.
public final class Session {
    public private(set) var scene: SoundScene
    public private(set) var isRunning = false
    public private(set) var lastError: String?

    private let outputDevice: AudioObjectID
    private let engine: SpatialEngine
    private var rings: [String: (left: MonoRingBuffer, right: MonoRingBuffer)] = [:]
    private var taps: [String: TapCapture] = [:]
    private var testMode = false

    public var outputName: String { stringProperty(outputDevice, kAudioObjectPropertyName) }
    public var sampleRate: Double { float64Property(outputDevice, kAudioDevicePropertyNominalSampleRate) }

    public init(scene: SoundScene) {
        self.scene = scene
        outputDevice = defaultOutputDevice()
        engine = SpatialEngine(sampleRate: float64Property(outputDevice, kAudioDevicePropertyNominalSampleRate))
        for s in scene.all { installVoice(s.id) }
        applyAll()
    }

    // MARK: ciclo de vida

    public func start() {
        guard !isRunning else { return }
        do { try engine.start() } catch {
            lastError = "motor de áudio: \(error)"
            return
        }
        isRunning = true
        lastError = nil
        refresh()
    }

    /// Desliga o efeito: os taps somem e o som volta ao normal.
    public func stop() {
        guard isRunning else { return }
        for tap in taps.values { tap.stop() }
        taps.removeAll()
        engine.stop()
        isRunning = false
    }

    /// Acerta os taps com os processos que existem agora. Chame a cada ~2 s.
    public func refresh() {
        guard isRunning else { return }
        let apps = Dictionary(uniqueKeysWithValues: listAudioApps().map { ($0.id, $0) })
        var claimed: [AudioObjectID] = []
        for s in scene.apps {
            let processes = (apps[s.id]?.processes ?? []).sorted()
            claimed += processes
            ensureTap(s.id, processes.isEmpty ? nil : .processes(processes))
        }
        ensureTap(SoundScene.restID, .restOfSystem(excluding: claimed.sorted()))
    }

    private func ensureTap(_ id: String, _ target: TapCapture.Target?) {
        if let current = taps[id], current.target == target { return }
        taps[id]?.stop()
        taps[id] = nil
        guard let target, let ring = rings[id] else { return }
        let tap = TapCapture(target: target, outputDevice: outputDevice, left: ring.left, right: ring.right)
        if let error = tap.start() {
            lastError = error
            tap.stop()
        } else {
            taps[id] = tap
        }
    }

    /// Maior nível recente entre todos os taps (e zera), para saber se há som tocando.
    public func takePeak() -> Float {
        var maxValue: Float = 0
        for tap in taps.values {
            maxValue = max(maxValue, tap.peak.pointee)
            tap.peak.pointee = 0
        }
        return maxValue
    }

    // MARK: cena

    private func installVoice(_ id: String) {
        let left = MonoRingBuffer(), right = MonoRingBuffer()
        rings[id] = (left, right)
        engine.addVoice(id: id,
                        left: { out, count in left.read(into: out, count: count) },
                        right: { out, count in right.read(into: out, count: count) })
    }

    private func apply(_ s: SourceSetting) {
        engine.place(id: s.id, angle: s.angle, distance: s.distance, width: scene.width,
                     volume: (s.muted || testMode) ? 0 : s.volume)
    }

    private func applyAll() {
        engine.setAlgorithm(scene.algorithm)
        engine.setReverb(on: scene.reverbOn, levelDB: scene.reverbDB)
        for s in scene.all { apply(s) }
    }

    public func setScene(_ new: SoundScene) {
        let removed = Set(scene.apps.map(\.id)).subtracting(new.apps.map(\.id))
        let added = Set(new.apps.map(\.id)).subtracting(scene.apps.map(\.id))
        scene = new
        for id in removed {
            taps[id]?.stop(); taps[id] = nil
            engine.removeVoice(id: id); rings[id] = nil
        }
        for id in added { installVoice(id) }
        applyAll()
        if !removed.isEmpty || !added.isEmpty { refresh() }
    }

    public func setHeadYaw(degrees: Float) { engine.setHeadYaw(degrees: degrees) }

    // MARK: teste cego

    private final class Burst {
        var remaining = 0
        var seed: UInt64 = 99
        func fill(_ out: UnsafeMutablePointer<Float>, _ count: Int, rate: Int) {
            for i in 0..<count {
                guard remaining > 0 else { out[i] = 0; continue }
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                let noise = Float(Int64(bitPattern: seed >> 11) % 2000 - 1000) / 1500
                let fade = min(1, Float(remaining) / 2400, Float(rate / 2 - remaining + 1) / 2400)
                out[i] = noise * max(0, fade)
                remaining -= 1
            }
        }
    }
    private let burst = Burst()

    /// Toca um chiado curto em `angle`, silenciando o resto durante o teste. Chame `endTest()` depois.
    public func playBurst(angle: Float, distance: Float = 1.5) {
        let rate = Int(sampleRate)
        if !engine.hasVoice("teste") {
            engine.addVoice(id: "teste",
                            left: { [burst] out, count in burst.fill(out, count, rate: rate) },
                            right: { out, count in out.update(repeating: 0, count: count) })
        }
        testMode = true
        for s in scene.all { apply(s) }
        engine.place(id: "teste", angle: angle, distance: distance, width: 0, volume: 1)
        burst.remaining = rate / 2
    }

    public func endTest() {
        testMode = false
        engine.removeVoice(id: "teste")
        for s in scene.all { apply(s) }
    }
}
