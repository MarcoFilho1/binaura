import AnyspaceCore
import AppKit
import SwiftUI

/// Escala de espaçamento (múltiplos de 4) e raios usados em toda a interface.
enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let radius: CGFloat = 10
}

/// Texto em português para ângulos e distâncias, usado nas legendas de acessibilidade.
enum Describe {
    static func angle(_ degrees: Float) -> String {
        let a = Int(degrees.rounded())
        if abs(a) <= 2 { return "à frente" }
        if abs(a) >= 178 { return "atrás" }
        return a > 0 ? "\(a)° à direita" : "\(-a)° à esquerda"
    }

    static func meters(_ value: Float) -> String {
        let text = value.formatted(.number.precision(.fractionLength(0...2)))
        return "\(text) m"
    }
}

/// Ícone de uma fonte: o ícone real do app quando existe; senão um símbolo.
@MainActor
enum SourceIcons {
    private static var cache: [String: NSImage] = [:]

    static func image(for id: String) -> NSImage? {
        if let hit = cache[id] { return hit }
        guard !id.hasPrefix("net:"), id != SoundScene.restID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        cache[id] = icon
        return icon
    }

    static func symbol(for id: String) -> String {
        if id == SoundScene.restID { return "speaker.wave.2.fill" }
        if id.hasPrefix("net:") { return "dot.radiowaves.left.and.right" }
        return "app.dashed"
    }
}

struct SourceIconView: View {
    let id: String
    var size: CGFloat = 24

    var body: some View {
        Group {
            if let image = SourceIcons.image(for: id) {
                Image(nsImage: image).resizable().interpolation(.high)
            } else {
                Image(systemName: SourceIcons.symbol(for: id))
                    .resizable().scaledToFit().padding(size * 0.2)
                    .foregroundStyle(.secondary)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
