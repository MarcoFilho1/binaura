import AppKit
import SwiftUI

/// Ícone do app, desenhado em código (1024×1024): os anéis do palco, você no centro com o cone de visão,
/// e as duas fontes (esquerda e direita) que dão o "bi" de binaural. Gerado por `Binaura --icon PASTA`.
struct AppIconArt: View {
    private let canvas: CGFloat = 1024
    private var body_: CGFloat { 824 }          // área do ícone na grade do macOS
    private var center: CGPoint { CGPoint(x: canvas / 2, y: canvas / 2 + 6) }

    var body: some View {
        ZStack {
            // Corpo do ícone
            RoundedRectangle(cornerRadius: 186, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.36, green: 0.55, blue: 1.0),
                                              Color(red: 0.15, green: 0.26, blue: 0.82)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: body_, height: body_)
                .shadow(color: .black.opacity(0.30), radius: 26, y: 14)
            // Brilho suave no topo, como nos ícones nativos
            RoundedRectangle(cornerRadius: 186, style: .continuous)
                .fill(LinearGradient(colors: [.white.opacity(0.20), .clear], startPoint: .top, endPoint: .center))
                .frame(width: body_, height: body_)

            Canvas { ctx, _ in
                let c = center
                // Anéis
                for (r, a) in [(120.0, 0.34), (210.0, 0.24), (300.0, 0.15)] {
                    ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                               with: .color(.white.opacity(a)), lineWidth: 14)
                }
                // Cone de visão (70°, para cima)
                var cone = Path()
                cone.move(to: c)
                for step in 0...28 {
                    let angle = (-125.0 + Double(step) * 70.0 / 28.0) * .pi / 180
                    cone.addLine(to: CGPoint(x: c.x + cos(angle) * 300, y: c.y + sin(angle) * 300))
                }
                cone.closeSubpath()
                ctx.fill(cone, with: .radialGradient(Gradient(colors: [.white.opacity(0.55), .white.opacity(0)]),
                                                     center: c, startRadius: 0, endRadius: 300))
                // Alto-falantes virtuais: um arco em cada lado, no anel do meio
                for side in [-1.0, 1.0] {
                    var arc = Path()
                    for step in 0...20 {
                        let deg = side * (28.0 + Double(step) * 42.0 / 20.0)      // de 28° a 70° de cada lado
                        let a = (deg - 90) * .pi / 180
                        let p = CGPoint(x: c.x + cos(a) * 210, y: c.y + sin(a) * 210)
                        step == 0 ? arc.move(to: p) : arc.addLine(to: p)
                    }
                    ctx.stroke(arc, with: .color(.white.opacity(0.95)), style: StrokeStyle(lineWidth: 30, lineCap: .round))
                }
                // Você
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - 62, y: c.y - 62, width: 124, height: 124)), with: .color(.white))
                var nub = Path()
                nub.move(to: CGPoint(x: c.x, y: c.y - 40))
                nub.addLine(to: CGPoint(x: c.x - 22, y: c.y + 6))
                nub.addLine(to: CGPoint(x: c.x + 22, y: c.y + 6))
                nub.closeSubpath()
                ctx.fill(nub, with: .color(Color(red: 0.20, green: 0.34, blue: 0.92)))
            }
        }
        .frame(width: canvas, height: canvas)
    }
}

@MainActor
enum IconExport {
    static func run(into folder: String) {
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        let renderer = ImageRenderer(content: AppIconArt())
        renderer.scale = 1
        renderer.isOpaque = false
        guard let tiff = renderer.nsImage?.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            fputs("erro: não consegui desenhar o ícone\n", stderr); exit(1)
        }
        let url = URL(fileURLWithPath: "\(folder)/icon-1024.png")
        try? png.write(to: url)
        print("Ícone em \(url.path) (\(rep.pixelsWide)×\(rep.pixelsHigh))")
        exit(0)
    }
}
