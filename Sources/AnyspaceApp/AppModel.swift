import AnyspaceCore
import AppKit
import Foundation
import ServiceManagement

/// Valor atualizado pela thread da câmera e lido pela interface.
final class HeadValue: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Float = 0
    func set(_ v: Float) { lock.lock(); value = v; lock.unlock() }
    func get() -> Float { lock.lock(); defer { lock.unlock() }; return value }
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
            session.setHeadYaw(degrees: angle)
        }
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
        guard effectOn else { return }
        session.refresh()
        if let error = session.lastError { message = error }

        // Economia de bateria: a câmera só fica ligada quando há som tocando.
        let level = session.takePeak()
        idleSeconds = level > 0.001 ? 0 : idleSeconds + 2
        let wantCamera = scene.headTracking && idleSeconds < 10
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
                    }
                }
            }
        } else if !wantCamera && head.isRunning {
            head.stop()
            headStatus = scene.headTracking ? "Câmera pausada: sem som tocando" : "Rastreio desligado"
        }
    }

    private func refreshHead() {
        guard head.isRunning else {
            if headAngle != 0 { headAngle = 0 }
            return
        }
        headAngle = headValue.get()
        let stats = head.takeStats()
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
        if !scene.headTracking && head.isRunning {
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
