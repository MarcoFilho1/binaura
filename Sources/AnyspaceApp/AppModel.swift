import AnyspaceCore
import AVFoundation
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
    @Published var debugCameraOpen = false { didSet { tick() } }
    private var lastCamera = ""
    private var lastInvert = false
    var previewSession: AVCaptureSession? { head.previewSession }

    let session: Session
    private let head: HeadController
    private let headValue = HeadValue()
    private var idleSeconds = 0
    private var saveTask: DispatchWorkItem?
    private var timers: [Timer] = []

    init(startEffect: Bool) {
        let scene = SceneStore.load()
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
        headValue.setApply(scene.headTracking)
        cameras = HeadTracker.cameras().map(\.localizedName)
        timers.append(Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        })
        timers.append(Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshHead() }
        })
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
            headStatus = "Rastreio desligado"
        }
    }

    func shutdown() {
        head.stop()
        session.stop()
    }

    // MARK: ciclo periódico

    private func tick() {
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
        if wantCamera && !head.isRunning {
            headStatus = "Ligando a câmera…"
            head.start(cameraName: scene.cameraName, invert: scene.invertHead) { [weak self] error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.message = "Câmera: \(error)"
                        self.headStatus = "Erro de câmera"
                        self.scene.headTracking = false
                    } else {
                        self.headStatus = "Olhe para a tela por 2 s (calibrando)"
                        self.objectWillChange.send()
                    }
                }
            }
        } else if !wantCamera && head.isRunning {
            head.stop()
            headStatus = scene.headTracking ? "Câmera pausada: sem som tocando" : "Rastreio desligado"
            headRaw = nil; faceBox = nil
        }
    }

    private func refreshHead() {
        guard head.isRunning else {
            if headAngle != 0 { headAngle = 0 }
            return
        }
        headAngle = headValue.get()
        let stats = head.takeStats()
        headRaw = stats.raw
        faceBox = stats.box
        if stats.frames > 0 {
            headStatus = stats.faces == 0 ? "Rosto não encontrado" : String(format: "Cabeça %+.0f°", stats.filtered)
        }
    }

    // MARK: cena

    private func sceneChanged() {
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
    }

    func move(_ id: String, angle: Float, distance: Float) {
        guard var s = scene.all.first(where: { $0.id == id }) else { return }
        s.angle = angle
        s.distance = distance
        scene.update(s)
    }

    func addApp(_ app: AudioApp) {
        guard !scene.apps.contains(where: { $0.id == app.id }) else { return }
        // Entra à esquerda, alternando de lado, para não nascer em cima de outra fonte.
        let angle: Float = scene.apps.count % 2 == 0 ? -60 : 60
        scene.apps.append(SourceSetting(id: app.id, name: app.name, angle: angle, distance: 1.5))
    }

    func addNetworkSource(port: UInt16) {
        let id = "net:\(port)"
        guard !scene.apps.contains(where: { $0.id == id }) else { return }
        scene.apps.append(SourceSetting(id: id, name: "Rede \(port)", angle: -80, distance: 1.5))
        if effectOn { session.start() }
        message = session.lastError
    }

    func removeApp(_ id: String) { scene.apps.removeAll { $0.id == id } }

    func calibrate() { head.calibrate(); headStatus = "Centro recalibrado" }

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
