import AVFoundation
import BinauraCore
import AppKit
import Foundation
import ServiceManagement

/// Valor atualizado pela thread da câmera e lido pela interface.
final class HeadValue: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Float = 0
    private var apply = false
    func set(_ v: Float) { lock.lock(); value = v; lock.unlock() }
    func get() -> Float { lock.lock(); defer { lock.unlock() }; return value }
    /// Só gira o espaço quando o acompanhamento está ligado (a câmera de debug não deve girar o som).
    func setApply(_ on: Bool) { lock.lock(); apply = on; lock.unlock() }
    func shouldApply() -> Bool { lock.lock(); defer { lock.unlock() }; return apply }
}

/// Problema que a pessoa resolve fora do app (nas permissões do macOS).
enum PermissionIssue {
    case audio, camera

    var settingsURL: URL {
        switch self {
        case .audio: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AudioCapture")!
        case .camera: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var scene: SoundScene { didSet { sceneChanged() } }
    @Published var effectOn = false
    @Published var availableApps: [AudioApp] = []
    @Published var headAngle: Float = 0
    @Published var headStatus = "Rastreio desligado"
    @Published var message: String?
    @Published var cameras: [String] = []
    @Published var headRaw: Float?
    @Published var faceBox: CGRect?
    @Published var levels: [String: Float] = [:]
    @Published var selectedID: String? = SoundScene.restID
    @Published var faceDetail: FaceDetail?
    @Published var cameraAccess: AVAuthorizationStatus = HeadTracker.authorization
    @Published var debugCameraOpen = false { didSet { head.setLandmarks(debugCameraOpen); tick() } }
    private var requestingCamera = false
    @Published var outputName = ""
    @Published var showBlindTest = false
    /// Incrementa quando algo fora do palco seleciona uma fonte, para as setas do teclado passarem a valer.
    @Published var stageFocusRequest = 0

    let session: Session
    let isPreview: Bool
    private let head: HeadController
    private let headValue = HeadValue()
    private var idleSeconds = 0
    private var lastCamera = ""
    private var lastInvert = false
    private var saveTask: DispatchWorkItem?
    private var timers: [Timer] = []

    var previewSession: AVCaptureSession? { head.previewSession }

    /// `preview` desliga tudo o que toca em áudio, câmera e disco, para gerar capturas de tela com dados de exemplo.
    init(startEffect: Bool, preview: SoundScene? = nil) {
        isPreview = preview != nil
        if preview == nil { SceneStore.migrateLegacyScene() }
        let scene = preview ?? SceneStore.load()
        self.scene = scene
        session = Session(scene: scene)
        let value = headValue
        let session = session
        head = HeadController { angle in
            value.set(angle)
            if value.shouldApply() { session.setHeadYaw(degrees: angle) }
        }
        lastCamera = scene.cameraName
        lastInvert = scene.invertHead
        lastHeadTracking = scene.headTracking
        headValue.setApply(scene.headTracking)
        outputName = session.outputName
        guard !isPreview else { return }

        cameras = HeadTracker.cameras().map(\.localizedName)
        timers.append(Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        })
        timers.append(Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshFast() }
        })
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.cameraAccess = HeadTracker.authorization
                if self.cameraAccess == .authorized, self.message?.hasPrefix("Câmera: permissão") == true { self.message = nil }
                self.tick()
            }
        }
        if startEffect { setEffect(true) }
        tick()
    }

    // MARK: efeito ligado/desligado

    func setEffect(_ on: Bool) {
        if on {
            session.start()
            message = session.lastError
            effectOn = session.isRunning
        } else {
            head.stop()
            session.stop()
            effectOn = false
            levels = [:]
            headStatus = "Rastreio desligado"
        }
    }

    func shutdown() {
        head.stop()
        session.stop()
    }

    // MARK: ciclo periódico

    private func tick() {
        guard !isPreview else { return }
        if effectOn != session.isRunning { effectOn = session.isRunning }
        outputName = session.outputName
        availableApps = listAudioApps()
        cameras = HeadTracker.cameras().map(\.localizedName)
        if effectOn {
            session.refresh()
            if let error = session.lastError { message = error }
        }

        // Economia de bateria: a câmera só fica ligada quando há som tocando (ou com a janela de debug aberta).
        let level = effectOn ? session.takePeak() : 0
        idleSeconds = level > 0.001 ? 0 : idleSeconds + 2
        let wantCamera = debugCameraOpen || (effectOn && scene.headTracking && idleSeconds < 10)
        cameraAccess = HeadTracker.authorization
        if wantCamera && !head.isRunning && cameraAccess == .notDetermined {
            // Primeira vez: traz o app para a frente e pede a permissão agora, em vez de esperar o próximo ciclo.
            guard !requestingCamera else { return }
            requestingCamera = true
            headStatus = "Responda ao pedido de acesso à câmera"
            NSApp.activate(ignoringOtherApps: true)
            AVCaptureDevice.requestAccess(for: .video) { [weak self] _ in
                Task { @MainActor in
                    self?.requestingCamera = false
                    self?.cameraAccess = HeadTracker.authorization
                    self?.tick()
                }
            }
        } else if wantCamera && !head.isRunning && (cameraAccess == .denied || cameraAccess == .restricted) {
            // Não adianta tentar de novo: só os Ajustes do Sistema resolvem. Mantém a escolha da pessoa ligada.
            headStatus = "Erro: permissão da câmera"
            if message == nil {
                message = "Câmera: permissão negada. Libere o Binaura em Ajustes do Sistema > Privacidade e Segurança > Câmera."
            }
        } else if wantCamera && !head.isRunning {
            headStatus = "Ligando a câmera…"
            head.start(cameraName: scene.cameraName, invert: scene.invertHead) { [weak self] error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.message = "Câmera: \(error)"
                        self.headStatus = "Erro: câmera indisponível"
                    } else {
                        self.headStatus = "Olhe para a tela por 2 s (calibrando)"
                    }
                }
            }
        } else if !wantCamera && head.isRunning {
            head.stop()
            headStatus = scene.headTracking ? "Câmera pausada: sem som tocando" : "Rastreio desligado"
            headRaw = nil; faceBox = nil; faceDetail = nil
        }
    }

    private func refreshFast() {
        if effectOn { levels = session.takeLevels() }
        guard head.isRunning else {
            if headAngle != 0 { headAngle = 0 }
            return
        }
        headAngle = headValue.get()
        let stats = head.takeStats()
        headRaw = stats.raw
        faceBox = stats.box
        faceDetail = stats.detail
        if stats.frames > 0 {
            headStatus = stats.faces == 0 ? "Rosto não encontrado" : "Acompanhando a cabeça"
        }
    }

    // MARK: cena

    private var lastHeadTracking = false

    private func sceneChanged() {
        guard !isPreview else { return }
        if scene.headTracking != lastHeadTracking {
            lastHeadTracking = scene.headTracking
            if scene.headTracking { message = nil }   // um aviso antigo de câmera não vale mais
            DispatchQueue.main.async { [weak self] in self?.tick() }
        }
        session.setScene(scene)
        saveTask?.cancel()
        let snapshot = scene
        let task = DispatchWorkItem { SceneStore.save(snapshot) }
        saveTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: task)
        headValue.setApply(scene.headTracking)
        // Trocar de câmera ou inverter o sentido reinicia o rastreio na hora.
        if scene.cameraName != lastCamera || scene.invertHead != lastInvert {
            lastCamera = scene.cameraName
            lastInvert = scene.invertHead
            if head.isRunning { head.stop(); headStatus = "Trocando de câmera…" }
            DispatchQueue.main.async { [weak self] in self?.tick() }
        } else if !scene.headTracking && !debugCameraOpen && head.isRunning {
            head.stop()
            headStatus = "Rastreio desligado"
        }
        if let selectedID, !scene.all.contains(where: { $0.id == selectedID }) { self.selectedID = SoundScene.restID }
    }

    func source(_ id: String) -> SourceSetting? { scene.all.first { $0.id == id } }

    func update(_ id: String, _ change: (inout SourceSetting) -> Void) {
        guard var s = source(id) else { return }
        change(&s)
        scene.update(s)
    }

    func move(_ id: String, angle: Float, distance: Float) {
        update(id) { $0.angle = angle; $0.distance = distance }
    }

    /// Alternativa por teclado ao arrastar: gira (em graus) e afasta (em metros).
    func nudge(_ id: String, angle: Float = 0, distance: Float = 0) {
        update(id) {
            var a = $0.angle + angle
            if a > 180 { a -= 360 }
            if a < -180 { a += 360 }
            $0.angle = a
            $0.distance = min(max($0.distance + distance, 0.5), 4)
        }
    }

    func addApp(_ app: AudioApp) {
        guard !scene.apps.contains(where: { $0.id == app.id }) else { return }
        // Entra de um lado, alternando, para não nascer em cima de outra fonte.
        let angle: Float = scene.apps.count % 2 == 0 ? -60 : 60
        scene.apps.append(SourceSetting(id: app.id, name: app.name, angle: angle, distance: 1.5))
        selectedID = app.id
    }

    func addNetworkSource(port: UInt16) {
        let id = "net:\(port)"
        guard !scene.apps.contains(where: { $0.id == id }) else { return }
        scene.apps.append(SourceSetting(id: id, name: "Rede \(port)", angle: -80, distance: 1.5))
        selectedID = id
        if effectOn { session.start() }
        message = session.lastError
    }

    func removeApp(_ id: String) { scene.apps.removeAll { $0.id == id } }

    // MARK: perfis

    func saveProfile(_ name: String) { scene.saveProfile(named: name) }
    func applyProfile(_ name: String) { scene.applyProfile(named: name) }
    func deleteProfile(_ name: String) { scene.deleteProfile(named: name) }

    /// Perfil cujo conteúdo é idêntico ao estado atual (para marcar no menu).
    var activeProfileName: String? {
        scene.profiles.first {
            $0.rest == scene.rest && $0.apps == scene.apps && $0.width == scene.width
                && $0.reverbOn == scene.reverbOn && $0.reverbDB == scene.reverbDB && $0.algorithm == scene.algorithm
        }?.name
    }

    // MARK: câmera

    func calibrate() { head.calibrate(); headStatus = "Centro recalibrado" }

    // MARK: avisos

    /// Quando a mensagem de erro aponta para uma permissão, a interface oferece o atalho para os Ajustes.
    var permissionIssue: PermissionIssue? {
        guard let message else { return nil }
        if message.localizedCaseInsensitiveContains("câmera") && message.localizedCaseInsensitiveContains("permiss") { return .camera }
        if message.localizedCaseInsensitiveContains("permiss") || message.localizedCaseInsensitiveContains("tap") { return .audio }
        return nil
    }

    // MARK: abrir no login

    var launchesAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            objectWillChange.send()
        } catch {
            message = "Abrir no login: \(error.localizedDescription)"
        }
    }
}
