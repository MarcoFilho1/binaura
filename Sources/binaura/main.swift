import BinauraCore
import Foundation

// Binaura (linha de comando): o som do sistema vira uma fonte estéreo em um ponto do espaço 3D.
//
//   --angle N      direção em graus: 0 frente, 90 direita, -90 esquerda, 180 atrás (padrão 0)
//   --distance D   distância em metros (padrão 1)
//   --width W      abertura do estéreo em graus (padrão 30; 0 = tudo em um ponto só)
//   --head         liga o rastreio da cabeça pela webcam (o espaço fica parado quando você vira)
//   --camera NOME  escolhe a câmera pelo nome (ex.: --camera C922); padrão: a do Mac
//   --invert       volta ao sentido bruto da câmera (o padrão já é invertido: testado com o Mac e a C922)
//   --send HOST:PORTA --password SENHA   em vez de tocar, envia o som deste Mac para outro Binaura pela rede
//   --seconds N    encerra sozinho e devolve o som ao normal
//   Para recalibrar o centro da cabeça: pkill -USR1 BinauraCLI

setvbuf(stdout, nil, _IOLBF, 0)

func option(_ name: String) -> String? {
    guard let i = CommandLine.arguments.firstIndex(of: name), CommandLine.arguments.count > i + 1 else { return nil }
    return CommandLine.arguments[i + 1]
}

if let path = option("--log-yaw") {
    // Diagnóstico: grava, quadro a quadro, o yaw do Vision e razões geométricas do rosto em um CSV.
    let seconds = option("--seconds").flatMap(Double.init) ?? 25
    let lock = NSLock()
    var rows = ["t,visionYawDeg,pitchDeg,rollDeg,f_nose,f_median,f_eyes,f_asym,faceW,boxW,boxH"]
    let start = Date()
    let tracker = HeadTracker(invert: false) { _ in }
    tracker.onDetail = { detail in
        let t = String(format: "%.3f", Date().timeIntervalSince(start))
        lock.lock(); defer { lock.unlock() }
        guard let d = detail else { rows.append("\(t),,,,,,,,,,"); return }
        func v(_ x: Float?) -> String { x.map { String(format: "%.5f", $0) } ?? "" }
        rows.append([t, v(d.rawYawDeg), v(d.pitch), v(d.roll), v(d.features["f_nose"]), v(d.features["f_median"]),
                     v(d.features["f_eyes"]), v(d.features["f_asym"]), v(d.features["faceW"]),
                     String(format: "%.4f", d.box.width), String(format: "%.4f", d.box.height)].joined(separator: ","))
    }
    tracker.setLandmarks(true)
    tracker.start(cameraNameContains: option("--camera")) { error in
        if let error { fputs("erro de câmera: \(error)\n", stderr); exit(1) }
        print("Gravando por \(Int(seconds)) s. Olhe para a tela e vire a cabeça devagar, como combinado.")
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
        tracker.stop()
        lock.lock(); let text = rows.joined(separator: "\n"); lock.unlock()
        try? text.write(toFile: (path as NSString).expandingTildeInPath, atomically: true, encoding: .utf8)
        print("Gravado em \(path) (\(rows.count - 1) quadros).")
        exit(0)
    }
    RunLoop.main.run()
}

if let target = option("--send") {
    // Modo remetente: captura o som do sistema (sem silenciá-lo aqui) e manda por UDP.
    let parts = target.split(separator: ":")
    guard parts.count == 2, let port = UInt16(parts[1]), let password = option("--password") else {
        fputs("uso: --send HOST:PORTA --password SENHA\n", stderr); exit(2)
    }
    let left = MonoRingBuffer(), right = MonoRingBuffer()
    let tap = TapCapture(target: .restOfSystem(excluding: []), outputDevice: defaultOutputDevice(),
                         left: left, right: right, muteOriginal: false)
    if let error = tap.start() { fputs("erro: \(error)\n", stderr); exit(1) }
    let sender = UDPAudioSender(host: String(parts[0]), port: port, password: password, left: left, right: right)
    sender.start()
    print("Enviando o som deste Mac para \(target). Ctrl+C para sair.")
    if let seconds = option("--seconds").flatMap(Double.init) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { sender.stop(); tap.stop(); exit(0) }
    }
    signal(SIGINT) { _ in exit(0) }
    RunLoop.main.run()
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
    head.start(cameraName: option("--camera"), invert: !CommandLine.arguments.contains("--invert")) { error in
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
