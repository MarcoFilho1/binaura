import BinauraCore
import AppKit
import SwiftUI

/// Gera capturas das telas com dados de exemplo (sem áudio, câmera nem disco) para revisar o visual.
@MainActor
enum Snapshot {
    static func sampleScene() -> SoundScene {
        var scene = SoundScene()
        scene.rest = SourceSetting(id: SoundScene.restID, name: "Resto do sistema", angle: -150, distance: 3, volume: 0.6)
        scene.apps = [
            SourceSetting(id: "com.google.Chrome", name: "Google Chrome", angle: 8, distance: 1.5, volume: 0.9),
            SourceSetting(id: "com.apple.Music", name: "Música", angle: 62, distance: 2.5, volume: 0.7),
            SourceSetting(id: "com.apple.Safari", name: "Safari", angle: -58, distance: 2, volume: 0.8, muted: true),
        ]
        scene.headTracking = true
        scene.saveProfile(named: "Trabalho")
        scene.saveProfile(named: "Filme")
        return scene
    }

    static func run(into folder: String) {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)

        let model = AppModel(startEffect: false, preview: sampleScene())
        model.effectOn = true
        model.headAngle = 24
        model.headStatus = "Acompanhando a cabeça"
        model.levels = ["com.google.Chrome": 0.28, "com.apple.Music": 0.12, SoundScene.restID: 0.05]
        model.availableApps = []
        model.selectedID = "com.google.Chrome"
        model.cameras = ["MacBook Air Camera", "C922 Pro Stream Webcam"]
        model.outputName = "Melobuds MARCO"

        var shots: [(String, AnyView, NSSize)] = [
            ("janela", AnyView(MainWindowView()), NSSize(width: 1080, height: 700)),
            ("inspetor", AnyView(InspectorView().background(Color(nsColor: .windowBackgroundColor))), NSSize(width: 360, height: 780)),
            ("menu", AnyView(MenuBarPanel().background(Color(nsColor: .windowBackgroundColor))), NSSize(width: 300, height: 360)),
            ("boas-vindas", AnyView(WelcomeView {}.background(Color(nsColor: .windowBackgroundColor))), NSSize(width: 460, height: 640)),
            ("teste-cego", AnyView(BlindTestView().background(Color(nsColor: .windowBackgroundColor))), NSSize(width: 460, height: 340)),
            ("malha", AnyView(ZStack {
                LinearGradient(colors: [Color(white: 0.55), Color(white: 0.30)], startPoint: .top, endPoint: .bottom)
                FaceOverlay(detail: syntheticFace())
            }), NSSize(width: 640, height: 480)),
            ("camera", AnyView(CameraDebugView().background(Color(nsColor: .windowBackgroundColor))), NSSize(width: 480, height: 700)),
        ]
        let off = AppModel(startEffect: false, preview: sampleScene())
        off.message = "Não consegui capturar o som (permissão de áudio negada). Libere o Binaura em Ajustes do Sistema > Privacidade e Segurança > Gravação de Áudio do Sistema."
        shots.append(("janela-desligado", AnyView(MainWindowView().environmentObject(off)), NSSize(width: 1080, height: 700)))

        for (name, view, size) in shots {
            for dark in [false, true] {
                let content = name == "janela-desligado" ? view : AnyView(view.environmentObject(model))
                // Formulários com rolagem não saem na captura da janela; o ImageRenderer os desenha direto.
                if ["inspetor", "camera", "malha"].contains(name) {
                    let renderer = ImageRenderer(content: content.frame(width: size.width, height: size.height)
                        .environment(\.colorScheme, dark ? .dark : .light))
                    renderer.scale = 2
                    if let tiff = renderer.nsImage?.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
                       let png = rep.representation(using: .png, properties: [:]) {
                        try? png.write(to: URL(fileURLWithPath: "\(folder)/\(name)-\(dark ? "escuro" : "claro").png"))
                    }
                    continue
                }
                capture(name: "\(name)-\(dark ? "escuro" : "claro")", view: content, size: size,
                        appearance: NSAppearance(named: dark ? .darkAqua : .aqua)!, folder: folder)
            }
        }
        print("Capturas em \(folder)")
        exit(0)
    }

    /// Rosto sintético (sem câmera) para conferir o desenho da malha: elipses no lugar dos marcos do Vision.
    static func syntheticFace() -> FaceDetail? {
        let cx = 0.5, cy = 0.5
        func ellipse(_ x: Double, _ y: Double, _ a: Double, _ b: Double, _ n: Int, from: Double = 0, to: Double = 360) -> [CGPoint] {
            (0..<n).map { i in
                let th = (from + (to - from) * Double(i) / Double(max(n - 1, 1))) * .pi / 180
                return CGPoint(x: x + a * cos(th), y: y + b * sin(th))
            }
        }
        let contour = ellipse(cx, cy + 0.03, 0.17, 0.28, 17, from: 175, to: 365)
        let leftBrow = (0..<5).map { CGPoint(x: cx - 0.15 + 0.11 * Double($0) / 4, y: cy + 0.17 + 0.012 * sin(Double($0) * .pi / 4)) }
        let rightBrow = (0..<5).map { CGPoint(x: cx + 0.04 + 0.11 * Double($0) / 4, y: cy + 0.17 + 0.012 * sin(Double($0) * .pi / 4)) }
        let leftEye = ellipse(cx - 0.085, cy + 0.10, 0.037, 0.016, 6)
        let rightEye = ellipse(cx + 0.085, cy + 0.10, 0.037, 0.016, 6)
        let crest = (0..<4).map { CGPoint(x: cx, y: cy + 0.10 - 0.04 * Double($0)) }
        let nose = [CGPoint(x: cx - 0.04, y: cy - 0.07), CGPoint(x: cx, y: cy - 0.078), CGPoint(x: cx + 0.04, y: cy - 0.07)]
        let lips = ellipse(cx, cy - 0.15, 0.055, 0.022, 8)
        let median = (0..<5).map { CGPoint(x: cx, y: cy + 0.2 - 0.11 * Double($0)) }
        let pupils = [CGPoint(x: cx - 0.085, y: cy + 0.10), CGPoint(x: cx + 0.085, y: cy + 0.10)]
        guard let mesh = buildFaceMesh(contour: contour, leftBrow: leftBrow, rightBrow: rightBrow, leftEye: leftEye,
                                       rightEye: rightEye, noseCrest: crest, nose: nose, lips: lips, median: median, pupils: pupils)
        else { return nil }
        let box = CGRect(x: cx - 0.19, y: cy - 0.28, width: 0.38, height: 0.58)
        return FaceDetail(box: box, yaw: 12, pitch: 3, mesh: mesh,
                          meshTriangles: prunedTriangles(delaunayTriangles(mesh), points: mesh, maxEdge: 0.75 * box.width),
                          pupils: pupils, gazeYaw: 18, gazePitch: 4)
    }

    /// Abre a janela real com dados de exemplo e a mantém aberta por `seconds`, imprimindo o número dela
    /// para o `screencapture -l` (a captura do próprio app não pega formulários com rolagem).
    static func show(name: String, seconds: Double, dark: Bool) {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let model = AppModel(startEffect: false, preview: sampleScene())
        model.effectOn = true
        model.headAngle = 24
        model.headStatus = "Acompanhando a cabeça"
        model.levels = ["com.google.Chrome": 0.28, "com.apple.Music": 0.12, SoundScene.restID: 0.05]
        model.selectedID = "com.google.Chrome"
        model.cameras = ["MacBook Air Camera", "C922 Pro Stream Webcam"]
        model.outputName = "Melobuds MARCO"
        let root: AnyView
        var size = NSSize(width: 1080, height: 700)
        switch name {
        case "camera": root = AnyView(CameraDebugView().environmentObject(model)); size = NSSize(width: 480, height: 700)
        case "inspetor": root = AnyView(InspectorView().environmentObject(model)); size = NSSize(width: 360, height: 780)
        default: root = AnyView(MainWindowView().environmentObject(model))
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: root))
        window.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        window.title = "Binaura"
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.setContentSize(size)
        window.setFrameOrigin(NSPoint(x: 60, y: 60))
        app.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        print("WINDOW \(window.windowNumber)")
        fflush(stdout)
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
        exit(0)
    }

    private static func capture(name: String, view: AnyView, size: NSSize, appearance: NSAppearance, folder: String) {
        let host = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: host)
        window.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        window.appearance = appearance
        window.title = "Binaura"
        window.setContentSize(size)
        window.setFrameOrigin(NSPoint(x: 40, y: 80))
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        // Dá tempo para o SwiftUI montar toolbar, inspetor e formulários antes da captura.
        RunLoop.main.run(until: Date().addingTimeInterval(1.6))
        guard let frame = window.contentView?.superview else { return }
        frame.layoutSubtreeIfNeeded()
        guard let rep = frame.bitmapImageRepForCachingDisplay(in: frame.bounds) else { return }
        frame.cacheDisplay(in: frame.bounds, to: rep)
        if let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: "\(folder)/\(name).png"))
        }
        window.orderOut(nil)
    }
}
