import AnyspaceCore
import CoreAudio
import Foundation

// Anyspace: captura o som do Mac e o coloca em um ponto do espaço 3D no fone.
//
//   --angle N      direção da fonte em graus: 0 frente, 90 direita, -90 esquerda, 180 atrás (padrão 0)
//   --distance D   distância em metros (padrão 1)
//   --head         liga o rastreio da cabeça pela webcam (o espaço fica parado quando você vira)
//   --camera NOME  escolhe a câmera pelo nome (ex.: --camera C922); padrão: a do Mac
//   --invert       inverte o sentido do ângulo da cabeça (se a câmera for espelhada)
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

// Rastreio da cabeça: a webcam entrega o ângulo bruto, o filtro o suaviza e o ouvinte 3D gira.
// Ao iniciar, olhe para a tela: os primeiros 2 s definem o centro. Para recalibrar: pkill -USR1 anyspace
let headEnabled = CommandLine.arguments.contains("--head")
let headLock = NSLock()
var headFilter = HeadFilter()
var lastFrameTime = Date()
var rawYaw: Float?
var facesSeen = 0, framesSeen = 0
var tracker: HeadTracker?

if headEnabled {
    let cameraName = CommandLine.arguments.firstIndex(of: "--camera").flatMap {
        CommandLine.arguments.count > $0 + 1 ? CommandLine.arguments[$0 + 1] : nil
    }
    print("Câmeras: \(HeadTracker.cameras().map(\.localizedName))")
    var calibrationUntil = Date().addingTimeInterval(2)
    tracker = HeadTracker(invert: CommandLine.arguments.contains("--invert")) { yaw in
        headLock.lock()
        let now = Date()
        let dt = Float(min(now.timeIntervalSince(lastFrameTime), 0.5))
        lastFrameTime = now
        rawYaw = yaw
        framesSeen += 1
        if yaw != nil { facesSeen += 1 }
        let filtered = headFilter.update(raw: yaw, dt: dt)
        if now < calibrationUntil { headFilter.calibrate() }
        headLock.unlock()
        spatial.setHeadYaw(degrees: filtered)
    }
    tracker?.start(cameraNameContains: cameraName) { error in
        if let error { fputs("erro de câmera: \(error)\n", stderr) } else { print("Câmera ligada. Olhe para a tela por 2 s (calibração).") }
    }
    signal(SIGUSR1, SIG_IGN)
    let recalibrate = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
    recalibrate.setEventHandler {
        headLock.lock(); headFilter.calibrate(); headLock.unlock()
        print("Centro recalibrado.")
    }
    recalibrate.resume()
    withExtendedLifetime(recalibrate) {}
    calibrationUntil = Date().addingTimeInterval(2)
}

func shutdown() {
    tracker?.stop()
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
    var line = String(format: "nível %.3f ", level) + String(repeating: "█", count: min(30, Int(level * 30)))
    if headEnabled {
        headLock.lock()
        let raw = rawYaw, out = headFilter.output, seen = facesSeen, frames = framesSeen
        facesSeen = 0; framesSeen = 0
        headLock.unlock()
        let side = abs(out) < 5 ? "centro" : (out > 0 ? "direita" : "esquerda")
        line += String(format: " | cabeça bruta %@ filtrada %+.0f° (%@) | rosto em %d de %d quadros",
                       raw.map { String(format: "%+.0f°", $0) } ?? "—", out, side, seen, frames)
    }
    print(line)
}
_ = meter
RunLoop.main.run()
