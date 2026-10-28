import AVFoundation
import AnyspaceCore

// Verificação offline do espaço 3D: renderiza ruído em vários ângulos, sem usar o fone,
// e confere se o ouvido certo recebe o som mais forte e mais cedo.

let sampleRate = 48000.0
let frames = 48000 * 2

struct Measurement { let rmsLeft: Double; let rmsRight: Double; let lagSamples: Int }

func render(angle: Float, distance: Float) throws -> Measurement {
    var seed: UInt64 = 12345
    let engine = SpatialEngine(sampleRate: sampleRate) { out, count in
        for i in 0..<count {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            out[i] = Float(Int64(bitPattern: seed >> 11) % 2000 - 1000) / 4000
        }
    }
    engine.setSource(angleDegrees: angle, distance: distance)
    let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
    try engine.engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
    try engine.start()
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096)!

    var left = [Float](), right = [Float]()
    while left.count < frames {
        let status = try engine.engine.renderOffline(4096, to: buffer)
        guard status == .success else { throw NSError(domain: "render", code: Int(status.rawValue)) }
        let n = Int(buffer.frameLength)
        left += UnsafeBufferPointer(start: buffer.floatChannelData![0], count: n)
        right += UnsafeBufferPointer(start: buffer.floatChannelData![1], count: n)
    }
    engine.stop()

    // ignora o começo (ainda estabilizando)
    let l = Array(left[8192...]), r = Array(right[8192...])
    func rms(_ x: [Float]) -> Double { sqrt(x.reduce(0) { $0 + Double($1 * $1) } / Double(x.count)) }

    // lag > 0: o ouvido direito recebe o sinal ANTES do esquerdo
    var best = 0, bestValue = -Double.infinity
    for lag in -60...60 {
        var sum = 0.0
        let n = min(l.count, r.count) - 100
        for i in 100..<n { sum += Double(l[i + lag]) * Double(r[i]) }
        if sum > bestValue { bestValue = sum; best = lag }
    }
    return Measurement(rmsLeft: rms(l), rmsRight: rms(r), lagSamples: best)
}

func db(_ a: Double, _ b: Double) -> Double { 20 * log10(a / b) }

var failures = 0
func expect(_ ok: Bool, _ what: String) {
    print(ok ? "  ok     " : "  FALHOU ", what)
    if !ok { failures += 1 }
}

do {
    var ild: [Float: Double] = [:]
    print("Ângulo | nível D−E (dB) | adiantamento do ouvido direito (amostras)")
    for angle: Float in [-90, -45, 0, 45, 90, 180] {
        let m = try render(angle: angle, distance: 1)
        ild[angle] = db(m.rmsRight, m.rmsLeft)
        print(String(format: "%6.0f | %14.1f | %d", angle, ild[angle]!, m.lagSamples))
        if angle == 90 { expect(m.lagSamples > 5, "90°: ouvido direito recebe antes (>5 amostras)") }
        if angle == -90 { expect(m.lagSamples < -5, "-90°: ouvido esquerdo recebe antes") }
    }
    expect(ild[90]! > 3, "90°: direito mais forte que o esquerdo (>3 dB)")
    expect(ild[-90]! < -3, "-90°: esquerdo mais forte que o direito (>3 dB)")
    expect(abs(ild[0]!) < 1.5, "0°: equilibrado entre os ouvidos (<1,5 dB)")
    expect(abs(ild[180]!) < 1.5, "180°: equilibrado entre os ouvidos (<1,5 dB)")

    let near = try render(angle: 0, distance: 1), far = try render(angle: 0, distance: 4)
    let drop = db(far.rmsLeft + far.rmsRight, near.rmsLeft + near.rmsRight)
    print(String(format: "Distância 1 m → 4 m: %.1f dB", drop))
    expect(drop < -6, "mais longe fica mais baixo (<-6 dB)")
} catch {
    print("erro: \(error)")
    failures += 1
}

print(failures == 0 ? "\nTudo certo." : "\n\(failures) verificação(ões) falharam.")
exit(failures == 0 ? 0 : 1)
