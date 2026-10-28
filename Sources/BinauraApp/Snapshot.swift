import BinauraCore
import AppKit
import SwiftUI

/// Gera capturas das telas com dados de exemplo (sem áudio, câmera nem disco) para revisar o visual.
/// Janela sem borda que aceita foco, para os controles aparecerem ativos (azuis) na captura.
private final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

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

    /// Abre uma janela real do app com dados de exemplo e a mantém aberta por `seconds`, imprimindo o número dela
    /// para o `screencapture -l`. Nomes: main, menu, welcome, blind, camera (câmera ao vivo, sem áudio).
    /// A janela aparece na segunda tela, se houver, para não cobrir o trabalho de quem está usando o Mac.
    static func show(name: String, seconds: Double, dark: Bool) {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let live = name == "camera"
        let model = AppModel(startEffect: false, preview: live ? nil : sampleScene())
        if !live {
            model.effectOn = true
            model.headAngle = 24
            model.headStatus = "Acompanhando a cabeça"
            model.levels = ["com.google.Chrome": 0.28, "com.apple.Music": 0.12, SoundScene.restID: 0.05]
            model.selectedID = "com.google.Chrome"
            model.cameras = ["MacBook Air Camera", "C922 Pro Stream Webcam"]
            model.outputName = "Melobuds MARCO"
        }
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let screen = NSScreen.screens.dropFirst().first ?? NSScreen.main ?? NSScreen.screens[0]
        func place(_ window: NSWindow, _ size: NSSize) {
            window.appearance = appearance
            window.setContentSize(size)
            window.setFrameOrigin(NSPoint(x: screen.frame.minX + 80, y: screen.frame.minY + 120))
        }

        let window: NSWindow
        switch name {
        case "menu":
            // Painel da barra de menu sem a barra de título: borda arredondada e material de popover.
            let host = NSHostingView(rootView: MenuBarPanel().environmentObject(model))
            let size = host.fittingSize
            let w = KeyableWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
            w.isOpaque = false; w.backgroundColor = .clear; w.hasShadow = true
            let visual = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
            visual.material = .popover; visual.state = .active; visual.blendingMode = .behindWindow
            // Máscara arredondada de verdade (a do popover), para a sombra e os cantos saírem certos.
            visual.maskImage = NSImage(size: size, flipped: false) { rect in
                NSColor.black.setFill()
                NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12).fill()
                return true
            }
            host.frame = visual.bounds; host.autoresizingMask = [.width, .height]
            visual.addSubview(host)
            w.contentView = visual
            window = w
            place(window, size)
        case "welcome":
            window = NSWindow(contentViewController: NSHostingController(rootView: WelcomeView {}.environmentObject(model)))
            window.styleMask = [.titled, .fullSizeContentView]; window.titlebarAppearsTransparent = true
            window.title = ""; window.titleVisibility = .hidden
            place(window, NSSize(width: 460, height: 600))
        case "blind":
            window = NSWindow(contentViewController: NSHostingController(rootView: BlindTestView().environmentObject(model)))
            window.styleMask = [.titled, .fullSizeContentView]; window.titlebarAppearsTransparent = true
            window.title = ""; window.titleVisibility = .hidden
            place(window, NSSize(width: 460, height: 340))
        case "camera":
            window = NSWindow(contentViewController: NSHostingController(rootView: CameraDebugView().environmentObject(model)))
            window.styleMask = [.titled, .closable, .resizable]; window.title = "Câmera (debug)"
            place(window, NSSize(width: 480, height: 820))
        default:
            window = NSWindow(contentViewController: NSHostingController(rootView: MainWindowView().environmentObject(model)))
            window.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]; window.title = "Binaura"
            place(window, NSSize(width: 1080, height: 700))
        }
        // --animate: as fontes passeiam pelo palco e a cabeça gira sozinhas (para gravar o GIF principal sem mão humana).
        var ticker: Timer?
        if CommandLine.arguments.contains("--animate"), !live {
            let start = Date()
            ticker = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { _ in
                MainActor.assumeIsolated {
                    if !window.isKeyWindow { NSApp.activate(ignoringOtherApps: true); window.makeKey() }   // a gravação rouba o foco
                    let t = Date().timeIntervalSince(start)
                    model.move("com.google.Chrome", angle: Float(15 + 25 * sin(t * 0.55)), distance: Float(1.7 + 0.55 * sin(t * 0.8 + 1)))
                    model.move("com.apple.Music", angle: Float(100 + 30 * sin(t * 0.4 + 2)), distance: Float(2.8 + 0.5 * sin(t * 0.6)))
                    model.headAngle = Float(34 * sin(t * 0.45))
                    let pulse = { (phase: Double) in Float(0.05 + 0.25 * abs(sin(t * 3.1 + phase))) }
                    model.levels = ["com.google.Chrome": pulse(0), "com.apple.Music": pulse(1.7), SoundScene.restID: pulse(3.1) * 0.4]
                }
            }
        }
        _ = ticker
        app.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.invalidateShadow()
        print("WINDOW \(window.windowNumber)")
        fflush(stdout)
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
        model.shutdown()
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
        // Segundo método: PDF da janela, que também pega listas e formulários com rolagem.
        let pdf = frame.dataWithPDF(inside: frame.bounds)
        if let image = NSImage(data: pdf) {
            let scale: CGFloat = 2
            let w = Int(frame.bounds.width * scale), h = Int(frame.bounds.height * scale)
            if let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4,
                                          hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) {
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)
                image.draw(in: NSRect(x: 0, y: 0, width: w, height: h))
                NSGraphicsContext.restoreGraphicsState()
                if let png = out.representation(using: .png, properties: [:]) {
                    try? png.write(to: URL(fileURLWithPath: "\(folder)/\(name)-pdf.png"))
                }
            }
        }
        window.orderOut(nil)
    }
}
