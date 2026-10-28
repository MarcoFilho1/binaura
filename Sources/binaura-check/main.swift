import AVFoundation
import BinauraCore

// Verificação offline do espaço 3D: renderiza ruído em vários ângulos, sem usar o fone,
// e confere se o ouvido certo recebe o som mais forte e mais cedo.

let sampleRate = 48000.0
let frames = 48000 * 2

struct Measurement { let rmsLeft: Double; let rmsRight: Double; let lagSamples: Int }

func render(angle: Float, distance: Float, headYaw: Float = 0) throws -> Measurement {
    var seed: UInt64 = 12345
    let engine = SpatialEngine(sampleRate: sampleRate)
    let noise: SpatialEngine.Provider = { out, count in
        for i in 0..<count {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            out[i] = Float(Int64(bitPattern: seed >> 11) % 2000 - 1000) / 4000
        }
    }
    // Esquerdo e direito idênticos e abertura 0: um único ponto, como na fase 1.
    engine.addVoice(id: "a", left: noise, right: { out, count in out.update(repeating: 0, count: count) })
    engine.place(id: "a", angle: angle, distance: distance, width: 0, volume: 1)
    engine.setHeadYaw(degrees: headYaw)
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

    // Cabeça: com a fonte à frente, virar para a direita deixa o som no ouvido esquerdo (e vice-versa).
    let turnedRight = try render(angle: 0, distance: 1, headYaw: 45)
    let turnedLeft = try render(angle: 0, distance: 1, headYaw: -45)
    let ildRight = db(turnedRight.rmsRight, turnedRight.rmsLeft), ildLeft = db(turnedLeft.rmsRight, turnedLeft.rmsLeft)
    print(String(format: "Cabeça virada 45° à direita: D−E %.1f dB | à esquerda: %.1f dB", ildRight, ildLeft))
    expect(ildRight < -3, "cabeça à direita: fonte da frente passa para a esquerda")
    expect(ildLeft > 3, "cabeça à esquerda: fonte da frente passa para a direita")
    let compensated = try render(angle: 45, distance: 1, headYaw: 45)
    expect(abs(db(compensated.rmsRight, compensated.rmsLeft)) < 1.5, "fonte a 45° + cabeça virada 45°: fonte volta ao centro")
} catch {
    print("erro: \(error)")
    failures += 1
}


// Filtro da cabeça, com sequências sintéticas a 20 quadros por segundo.
print("\nEstéreo como dois alto-falantes virtuais")
func renderStereo(leftOnly: Bool, width: Float) throws -> Measurement {
    var seed: UInt64 = 7
    let engine = SpatialEngine(sampleRate: sampleRate)
    let noise: SpatialEngine.Provider = { out, count in
        for i in 0..<count {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            out[i] = Float(Int64(bitPattern: seed >> 11) % 2000 - 1000) / 4000
        }
    }
    let silence: SpatialEngine.Provider = { out, count in out.update(repeating: 0, count: count) }
    engine.addVoice(id: "s", left: leftOnly ? noise : silence, right: leftOnly ? silence : noise)
    engine.place(id: "s", angle: 0, distance: 1, width: width, volume: 1)
    let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
    try engine.engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
    try engine.start()
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096)!
    var l = 0.0, r = 0.0, n = 0
    for _ in 0..<24 {
        _ = try engine.engine.renderOffline(4096, to: buffer)
        for i in 0..<Int(buffer.frameLength) {
            l += Double(buffer.floatChannelData![0][i] * buffer.floatChannelData![0][i])
            r += Double(buffer.floatChannelData![1][i] * buffer.floatChannelData![1][i])
            n += 1
        }
    }
    engine.stop()
    return Measurement(rmsLeft: sqrt(l / Double(n)), rmsRight: sqrt(r / Double(n)), lagSamples: 0)
}
do {
    let onlyLeft = try renderStereo(leftOnly: true, width: 30)
    let onlyRight = try renderStereo(leftOnly: false, width: 30)
    let ildL = db(onlyLeft.rmsRight, onlyLeft.rmsLeft), ildR = db(onlyRight.rmsRight, onlyRight.rmsLeft)
    print(String(format: "Só canal esquerdo: D−E %.1f dB | só canal direito: %.1f dB", ildL, ildR))
    expect(ildL < -2, "canal esquerdo soa mais no ouvido esquerdo")
    expect(ildR > 2, "canal direito soa mais no ouvido direito")
} catch { print("erro: \(error)"); failures += 1 }

print("\nCena, mapa e processos")
var scene = SoundScene()
scene.apps.append(SourceSetting(id: "com.spotify.client", name: "Spotify", angle: -60, distance: 2.5, volume: 0.7, muted: true))
scene.width = 20
let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("binaura-\(UUID().uuidString).json")
SceneStore.save(scene, to: tmp)
expect(SceneStore.load(from: tmp) == scene, "cena salva e carregada em JSON é idêntica")
try? FileManager.default.removeItem(at: tmp)
expect(SceneStore.load(from: tmp) == SoundScene(), "arquivo inexistente devolve a cena padrão")

for (angle, distance) in [(Float(0), Float(1)), (90, 2), (-135, 3), (180, 0.7)] {
    let p = MapGeometry.point(angle: angle, distance: distance, metersPerRadius: 4, radiusPixels: 150)
    let q = MapGeometry.polar(dx: p.dx, dy: p.dy, metersPerRadius: 4, radiusPixels: 150)
    expect(abs(q.angle - angle) < 0.01 || abs(abs(q.angle - angle) - 360) < 0.01, "mapa: ida e volta \(angle)° \(distance) m")
    expect(abs(q.distance - distance) < 0.01, "mapa: distância \(distance) m preservada")
}
let top = MapGeometry.polar(dx: 0, dy: -100, metersPerRadius: 4, radiusPixels: 150)
expect(abs(top.angle) < 0.01, "mapa: ponto acima do centro = frente (0°)")
let rightSide = MapGeometry.polar(dx: 100, dy: 0, metersPerRadius: 4, radiusPixels: 150)
expect(abs(rightSide.angle - 90) < 0.01, "mapa: ponto à direita = 90°")
expect(rootBundleID("com.google.Chrome.helper.Renderer") == "com.google.Chrome", "helper do Chrome agrupa no Chrome")
expect(rootBundleID("com.apple.WebKit.GPU") == "com.apple.Safari", "WebKit agrupa no Safari")
expect(rootBundleID("com.spotify.client") == "com.spotify.client", "app simples permanece igual")

print("\nPerfis")
var withProfiles = SoundScene()
withProfiles.rest.angle = -30
withProfiles.apps.append(SourceSetting(id: "com.google.Chrome", name: "Chrome", angle: 40, distance: 2))
withProfiles.width = 45
withProfiles.saveProfile(named: "Trabalho")
withProfiles.rest.angle = 70; withProfiles.apps.removeAll(); withProfiles.width = 10; withProfiles.reverbOn = false
withProfiles.saveProfile(named: "Filme")
expect(withProfiles.profiles.map(\.name) == ["Trabalho", "Filme"], "dois perfis salvos")
expect(withProfiles.applyProfile(named: "Trabalho") && withProfiles.rest.angle == -30 && withProfiles.apps.count == 1
       && withProfiles.width == 45 && withProfiles.reverbOn, "aplicar 'Trabalho' restaura posições, abertura e reverberação")
expect(withProfiles.applyProfile(named: "Filme") && withProfiles.rest.angle == 70 && withProfiles.apps.isEmpty, "aplicar 'Filme' restaura o outro estado")
withProfiles.saveProfile(named: "Filme")
expect(withProfiles.profiles.count == 2, "salvar com o mesmo nome substitui")
expect(!withProfiles.applyProfile(named: "inexistente"), "perfil inexistente não faz nada")
withProfiles.deleteProfile(named: "Filme")
expect(withProfiles.profiles.map(\.name) == ["Trabalho"], "apagar remove só o escolhido")
let profileURL = FileManager.default.temporaryDirectory.appendingPathComponent("binaura-p-\(UUID().uuidString).json")
SceneStore.save(withProfiles, to: profileURL)
expect(SceneStore.load(from: profileURL) == withProfiles, "perfis sobrevivem a salvar e carregar")
try? FileManager.default.removeItem(at: profileURL)
let oldJSON = #"{"rest":{"id":"rest","name":"Resto do sistema","angle":-21,"distance":0.5,"volume":1,"muted":false},"apps":[],"width":30}"#
let oldURL = FileManager.default.temporaryDirectory.appendingPathComponent("binaura-old-\(UUID().uuidString).json")
try? oldJSON.write(to: oldURL, atomically: true, encoding: .utf8)
let loadedOld = SceneStore.load(from: oldURL)
expect(loadedOld.rest.angle == -21 && loadedOld.profiles.isEmpty && loadedOld.algorithm == "HRTFHQ",
       "arquivo de versão antiga (sem campos novos) mantém o que existe e completa o resto")
try? FileManager.default.removeItem(at: oldURL)

expect(SceneStore.url.path.hasSuffix("Binaura/scene.json"), "a cena fica na pasta Binaura")

print("\nFila circular")
let ring = MonoRingBuffer(capacityPowerOfTwo: 1024, maxFill: 300, targetFill: 100)
let input = (0..<200).map { Float($0) }; var output = [Float](repeating: -1, count: 50)
input.withUnsafeBufferPointer { ring.write($0.baseAddress!, count: 200) }
output.withUnsafeMutableBufferPointer { ring.read(into: $0.baseAddress!, count: 50) }
expect(output[0] == 0 && output[49] == 49, "leitura devolve as amostras na ordem")
var tooMuch = [Float](repeating: 1, count: 400)
tooMuch.withUnsafeBufferPointer { ring.write($0.baseAddress!, count: 400) }
output.withUnsafeMutableBufferPointer { ring.read(into: $0.baseAddress!, count: 50) }
expect(output.allSatisfy { $0 == 1 }, "com excesso, o leitor pula para o áudio recente (atraso limitado)")
var starved = [Float](repeating: 5, count: 800)
starved.withUnsafeMutableBufferPointer { ring.read(into: $0.baseAddress!, count: 800) }
expect(starved.allSatisfy { $0 == 0 }, "sem áudio suficiente, devolve silêncio")

print("\nÁudio pela rede (loopback)")
let l0 = (0..<480).map { Float(sin(Double($0) * 0.05)) * 0.5 }, r0 = l0.map { -$0 }
let packet = AudioPacket.encode(sequence: 7, password: "segredo", left: l0, right: r0)
let decoded = AudioPacket.decode(packet, password: "segredo")
expect(decoded?.sequence == 7 && decoded?.left.count == 480, "pacote codifica e decodifica")
expect(zip(decoded?.left ?? [], l0).allSatisfy { abs($0 - $1) < 0.001 }, "erro de quantização abaixo de 0,001")
expect(AudioPacket.decode(packet, password: "errada") == nil, "senha errada é rejeitada")
expect(AudioPacket.decode(packet.dropLast(), password: "segredo") == nil, "pacote truncado é rejeitado")

do {
    let rxL = MonoRingBuffer(capacityPowerOfTwo: 65536, maxFill: 60000), rxR = MonoRingBuffer(capacityPowerOfTwo: 65536, maxFill: 60000)
    let receiver = try UDPAudioReceiver(port: 54871, password: "segredo", left: rxL, right: rxR)
    let ready = DispatchSemaphore(value: 0)
    receiver.start { ready.signal() }
    expect(ready.wait(timeout: .now() + 3) == .success, "receptor UDP abre a porta")

    let txL = MonoRingBuffer(), txR = MonoRingBuffer()
    l0.withUnsafeBufferPointer { txL.write($0.baseAddress!, count: 480) }
    r0.withUnsafeBufferPointer { txR.write($0.baseAddress!, count: 480) }
    let sender = UDPAudioSender(host: "127.0.0.1", port: 54871, password: "segredo", left: txL, right: txR)
    sender.start()
    Thread.sleep(forTimeInterval: 0.6)
    sender.stop()

    var got = [Float](repeating: 9, count: 480)
    got.withUnsafeMutableBufferPointer { rxL.read(into: $0.baseAddress!, count: 480) }
    expect(zip(got, l0).allSatisfy { abs($0 - $1) < 0.001 }, "áudio enviado chega igual ao receptor (canal esquerdo)")
    receiver.stop()

    let rejectL = MonoRingBuffer(), rejectR = MonoRingBuffer()
    let strict = try UDPAudioReceiver(port: 54872, password: "outra", left: rejectL, right: rejectR)
    let up = DispatchSemaphore(value: 0)
    strict.start { up.signal() }
    _ = up.wait(timeout: .now() + 3)
    l0.withUnsafeBufferPointer { txL.write($0.baseAddress!, count: 480) }
    let bad = UDPAudioSender(host: "127.0.0.1", port: 54872, password: "segredo", left: txL, right: txR)
    bad.start()
    Thread.sleep(forTimeInterval: 0.4)
    bad.stop()
    expect(strict.packetsAccepted == 0 && strict.packetsRejected > 0, "receptor ignora remetente com senha errada (\(strict.packetsRejected) rejeitados)")
    strict.stop()
} catch { print("erro de rede: \(error)"); failures += 1 }

print("Câmeras encontradas (sem ligar nenhuma): \(HeadTracker.cameras().map(\.localizedName))")

print("\nTroca de saída")
do {
    let session = Session(scene: SoundScene())
    session.rebuild(); session.rebuild()
    expect(!session.isRunning, "reconstruir sem estar ligado não liga o efeito nem cria taps")
    expect(SoundScene().invertHead, "sentido da cabeça padrão é o invertido")
}

print("\nOlhar na tela")
expect(screenPoint(gazeYaw: 0, gazePitch: 0) == (0, 0), "olhar à frente = centro da tela")
expect(screenPoint(gazeYaw: 15, gazePitch: 0).x == 0.5 && screenPoint(gazeYaw: -15, gazePitch: 0).x == -0.5, "15° à direita = meio caminho para a direita")
expect(screenPoint(gazeYaw: 90, gazePitch: -90) == (1, -1), "olhar muito fora encosta na borda")

print("\nFiltro da cabeça")
let dt: Float = 0.05
var step = HeadFilter()
for _ in 0..<10 { step.update(raw: 40, dt: dt) }
expect(abs(step.output - 40) < 3, "degrau de 40° é alcançado em 0,5 s (saída \(step.output))")

var noisy = HeadFilter()
var maxDrift: Float = 0
for i in 0..<200 {
    noisy.update(raw: (i % 2 == 0 ? 0.8 : -0.8), dt: dt)
    maxDrift = max(maxDrift, abs(noisy.output))
}
expect(maxDrift < 0.5, "ruído de ±0,8° não faz o som tremer (desvio máx \(maxDrift))")

var lost = HeadFilter()
for _ in 0..<20 { lost.update(raw: 30, dt: dt) }
let before = lost.output
for _ in 0..<20 { lost.update(raw: nil, dt: dt) }
expect(abs(lost.output - before) < 0.01, "rosto perdido por 1 s: mantém o último ângulo")
for _ in 0..<(20 * 8) { lost.update(raw: nil, dt: dt) }
expect(abs(lost.output) < 5, "rosto perdido por 9 s: volta ao centro (saída \(lost.output))")

var calibrated = HeadFilter()
for _ in 0..<40 { calibrated.update(raw: 15, dt: dt) }
calibrated.calibrate()
for _ in 0..<40 { calibrated.update(raw: 15, dt: dt) }
expect(abs(calibrated.output) < 1.5, "depois de calibrar, 15° passa a ser o centro")

var clamped = HeadFilter()
for _ in 0..<100 { clamped.update(raw: 170, dt: dt) }
expect(clamped.output <= 90.01, "ângulo limitado a 90°")

print(failures == 0 ? "\nTudo certo." : "\n\(failures) verificação(ões) falharam.")
exit(failures == 0 ? 0 : 1)
