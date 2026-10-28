import AVFoundation
import CoreAudio
import Foundation

/// Junta tudo: cena, taps por aplicativo, motor 3D. Use sempre da thread principal.
public final class Session {
    public private(set) var scene: SoundScene
    public private(set) var isRunning = false
    public private(set) var lastError: String?
    /// A interface usa isto para oferecer o atalho para os Ajustes do Sistema (sem depender do texto do erro).
    public private(set) var lastErrorNeedsAudioPermission = false

    private var outputDevice: AudioObjectID
    private var engine: SpatialEngine
    private var rebuildTask: DispatchWorkItem?
    private var listenerBlock: AudioObjectPropertyListenerBlock?
    private var rings: [String: (left: MonoRingBuffer, right: MonoRingBuffer)] = [:]
    private var taps: [String: TapCapture] = [:]
    private var receivers: [String: UDPAudioReceiver] = [:]
    private var testMode = false

    public var outputName: String { stringProperty(outputDevice, kAudioObjectPropertyName) }
    public var sampleRate: Double { float64Property(outputDevice, kAudioDevicePropertyNominalSampleRate) }

    public init(scene: SoundScene) {
        self.scene = scene
        outputDevice = defaultOutputDevice()
        engine = SpatialEngine(sampleRate: float64Property(outputDevice, kAudioDevicePropertyNominalSampleRate))
        for s in scene.all { installVoice(s.id) }
        applyAll()
        engine.setOutputKind(speakers: isBuiltInSpeaker(outputDevice))
        watchOutputChanges()
        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main) { [weak self] _ in
            self?.scheduleRebuild()
        }
    }

    // MARK: troca de saída (fone removido ou conectado)

    /// Quando o dispositivo de saída padrão muda, o motor antigo para e os apps ficariam mudos
    /// (o tap silencia o original). Então desligamos tudo e recomeçamos na nova saída.
    private func watchOutputChanges() {
        var addr = address(kAudioHardwarePropertyDefaultOutputDevice)
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.scheduleRebuild() }
        listenerBlock = block
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addr, DispatchQueue.main, block)
    }

    private func scheduleRebuild() {
        rebuildTask?.cancel()
        let task = DispatchWorkItem { [weak self] in self?.rebuildIfOutputChanged() }
        rebuildTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: task)
    }

    private func rebuildIfOutputChanged() {
        let current = defaultOutputDevice()
        // A notificação do motor também chega quando o dispositivo é o mesmo mas parou: reconstrói do mesmo jeito.
        guard current != outputDevice || (isRunning && !engine.engine.isRunning) else { return }
        rebuild()
    }

    public func rebuild() {
        let wasRunning = isRunning
        stop()                      // devolve o som aos apps antes de qualquer coisa
        outputDevice = defaultOutputDevice()
        engine = SpatialEngine(sampleRate: float64Property(outputDevice, kAudioDevicePropertyNominalSampleRate))
        rings.removeAll()
        for s in scene.all { installVoice(s.id) }
        applyAll()
        engine.setOutputKind(speakers: isBuiltInSpeaker(outputDevice))
        if wasRunning { start() }
    }

    // MARK: ciclo de vida

    public func start() {
        guard !isRunning else { return }
        do { try engine.start() } catch {
            lastError = String(localized: "motor de áudio: \(String(describing: error))")
            return
        }
        isRunning = true
        lastError = nil
        lastErrorNeedsAudioPermission = false
        startReceivers()
        refresh()
    }

    /// Desliga o efeito: os taps somem e o som volta ao normal.
    public func stop() {
        guard isRunning else { return }
        for tap in taps.values { tap.stop() }
        taps.removeAll()
        for r in receivers.values { r.stop() }
        receivers.removeAll()
        engine.stop()
        isRunning = false
    }

    /// Acerta os taps com os processos que existem agora. Chame a cada ~2 s.
    public func refresh() {
        guard isRunning else { return }
        let apps = Dictionary(uniqueKeysWithValues: listAudioApps().map { ($0.id, $0) })
        var claimed: [AudioObjectID] = []
        for s in scene.apps where SoundScene.networkPort(of: s.id) == nil {
            let processes = (apps[s.id]?.processes ?? []).sorted()
            claimed += processes
            ensureTap(s.id, processes.isEmpty ? nil : .processes(processes))
        }
        ensureTap(SoundScene.restID, .restOfSystem(excluding: claimed.sorted()))
    }

    private func startReceivers() {
        for s in scene.apps {
            guard let port = SoundScene.networkPort(of: s.id), receivers[s.id] == nil, let ring = rings[s.id] else { continue }
            guard !scene.networkPassword.isEmpty else { lastError = String(localized: "Defina uma senha para receber áudio pela rede"); continue }
            do {
                let receiver = try UDPAudioReceiver(port: port, password: scene.networkPassword, left: ring.left, right: ring.right)
                receiver.start()
                receivers[s.id] = receiver
            } catch { lastError = String(localized: "porta \(Int(port)): \(error.localizedDescription)") }
        }
    }

    private func ensureTap(_ id: String, _ target: TapCapture.Target?) {
        if let current = taps[id], current.target == target { return }
        taps[id]?.stop()
        taps[id] = nil
        guard let target, let ring = rings[id] else { return }
        let tap = TapCapture(target: target, outputDevice: outputDevice, left: ring.left, right: ring.right)
        if let error = tap.start() {
            lastError = error
            lastErrorNeedsAudioPermission = tap.failedAtTap
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

    /// Nível recente (0...1) de cada fonte, e zera. Chamado pela interface ~10 vezes por segundo.
    public func takeLevels() -> [String: Float] {
        var levels: [String: Float] = [:]
        for (id, tap) in taps {
            levels[id] = tap.meter.pointee
            tap.meter.pointee = 0
        }
        for (id, receiver) in receivers where levels[id] == nil { _ = receiver; levels[id] = 0 }
        return levels
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
            receivers[id]?.stop(); receivers[id] = nil
            engine.removeVoice(id: id); rings[id] = nil
        }
        for id in added { installVoice(id) }
        applyAll()
        if isRunning { startReceivers() }
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
