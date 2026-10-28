import AnyspaceCore
import CoreAudio
import Foundation

// Anyspace: captura o som do Mac e o coloca em um ponto do espaço 3D no fone.
//
//   --angle N      direção da fonte em graus: 0 frente, 90 direita, -90 esquerda, 180 atrás (padrão 0)
//   --distance D   distância em metros (padrão 1)
//   --seconds N    encerra sozinho e devolve o som ao normal

setvbuf(stdout, nil, _IOLBF, 0)

func option(_ name: String) -> Double? {
    guard let i = CommandLine.arguments.firstIndex(of: name), CommandLine.arguments.count > i + 1 else { return nil }
    return Double(CommandLine.arguments[i + 1])
}

let angle = Float(option("--angle") ?? 0)
let distance = Float(option("--distance") ?? 1)

let ring = MonoRingBuffer()
let capture = TapCapture()
print("Saída: \(stringProperty(capture.outputDevice, kAudioObjectPropertyName))")

let spatial = SpatialEngine(sampleRate: 48000) { out, count in ring.read(into: out, count: count) }
capture.start(into: ring)
if capture.sampleRate != 48000 {
    fputs("aviso: o dispositivo está em \(capture.sampleRate) Hz; esta versão espera 48000 Hz\n", stderr)
}

spatial.setSource(angleDegrees: angle, distance: distance)
do { try spatial.start() } catch {
    fputs("erro ao iniciar o motor de áudio: \(error)\n", stderr)
    capture.stop()
    exit(1)
}
print(String(format: "Fonte a %.0f° e %.1f m. Ctrl+C para sair.", angle, distance))

func shutdown() {
    spatial.stop()
    capture.stop()
    print("\nEncerrado; o som volta ao normal.")
    exit(0)
}

if let seconds = option("--seconds") {
    print("Encerra sozinho em \(Int(seconds)) s.")
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { shutdown() }
}

signal(SIGINT, SIG_IGN)
signal(SIGTERM, SIG_IGN)
let signals = [SIGINT, SIGTERM].map { sig -> DispatchSourceSignal in
    let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
    source.setEventHandler { shutdown() }
    source.resume()
    return source
}

let meter = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
    let level = capture.peak.pointee
    capture.peak.pointee = 0
    print(String(format: "nível %.3f ", level) + String(repeating: "█", count: min(30, Int(level * 30))))
}
_ = meter
RunLoop.main.run()
