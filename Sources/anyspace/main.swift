import AnyspaceCore
import Foundation

// Anyspace (linha de comando): o som do sistema vira uma fonte estéreo em um ponto do espaço 3D.
//
//   --angle N      direção em graus: 0 frente, 90 direita, -90 esquerda, 180 atrás (padrão 0)
//   --distance D   distância em metros (padrão 1)
//   --width W      abertura do estéreo em graus (padrão 30; 0 = tudo em um ponto só)
//   --head         liga o rastreio da cabeça pela webcam (o espaço fica parado quando você vira)
//   --camera NOME  escolhe a câmera pelo nome (ex.: --camera C922); padrão: a do Mac
//   --invert       inverte o sentido do ângulo da cabeça (se a câmera for espelhada)
//   --seconds N    encerra sozinho e devolve o som ao normal
//   Para recalibrar o centro da cabeça: pkill -USR1 AnyspaceCLI

setvbuf(stdout, nil, _IOLBF, 0)

func option(_ name: String) -> String? {
    guard let i = CommandLine.arguments.firstIndex(of: name), CommandLine.arguments.count > i + 1 else { return nil }
    return CommandLine.arguments[i + 1]
}

var scene = SoundScene()
scene.rest.angle = Float(option("--angle") ?? "") ?? 0
scene.rest.distance = Float(option("--distance") ?? "") ?? 1
scene.width = Float(option("--width") ?? "") ?? 30
scene.reverbOn = false

let session = Session(scene: scene)
print("Saída: \(session.outputName)")
if session.sampleRate != 48000 { print("Taxa do dispositivo: \(session.sampleRate) Hz") }
session.start()
if let error = session.lastError {
    fputs("erro: \(error)\n", stderr)
    exit(1)
}
print(String(format: "Fonte a %.0f° (abertura %.0f°) e %.1f m. Ctrl+C para sair.", scene.rest.angle, scene.width, scene.rest.distance))

let head = HeadController { session.setHeadYaw(degrees: $0) }
let headEnabled = CommandLine.arguments.contains("--head")
if headEnabled {
    print("Câmeras: \(HeadTracker.cameras().map(\.localizedName))")
    head.start(cameraName: option("--camera"), invert: CommandLine.arguments.contains("--invert")) { error in
        if let error { fputs("erro de câmera: \(error)\n", stderr) } else { print("Câmera ligada. Olhe para a tela por 2 s (calibração).") }
    }
}

func shutdown() {
    head.stop()
    session.stop()
    print("\nEncerrado; o som volta ao normal.")
    exit(0)
}

if let seconds = option("--seconds").flatMap(Double.init) {
    print("Encerra sozinho em \(Int(seconds)) s.")
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { shutdown() }
}

signal(SIGINT, SIG_IGN); signal(SIGTERM, SIG_IGN); signal(SIGUSR1, SIG_IGN)
let signals = [SIGINT, SIGTERM].map { sig -> DispatchSourceSignal in
    let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
    source.setEventHandler { shutdown() }
    source.resume()
    return source
}
let recalibrate = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
recalibrate.setEventHandler { head.calibrate(); print("Centro recalibrado.") }
recalibrate.resume()

let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
    session.refresh()
    let level = session.takePeak()
    var line = String(format: "nível %.3f ", level) + String(repeating: "█", count: min(30, Int(level * 30)))
    if headEnabled {
        let s = head.takeStats()
        let side = abs(s.filtered) < 5 ? "centro" : (s.filtered > 0 ? "direita" : "esquerda")
        line += String(format: " | cabeça bruta %@ filtrada %+.0f° (%@) | rosto em %d de %d quadros",
                       s.raw.map { String(format: "%+.0f°", $0) } ?? "—", s.filtered, side, s.faces, s.frames)
    }
    print(line)
}
_ = timer
RunLoop.main.run()
