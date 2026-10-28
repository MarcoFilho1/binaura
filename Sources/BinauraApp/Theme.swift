import BinauraCore
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

/// Texto para ângulos e distâncias, usado nas legendas de acessibilidade (traduzido pelo idioma do app).
enum Describe {
    static func angle(_ degrees: Float) -> String {
        let a = Int(degrees.rounded())
        if abs(a) <= 2 { return String(localized: "à frente") }
        if abs(a) >= 178 { return String(localized: "atrás") }
        return a > 0 ? String(localized: "\(a)° à direita") : String(localized: "\(-a)° à esquerda")
    }

    static func meters(_ value: Float) -> String {
        let text = value.formatted(.number.precision(.fractionLength(0...2)))
        return String(localized: "\(text) m")
    }
}

extension SourceSetting {
    /// O nome da fonte "Resto do sistema" é salvo em português; para exibir, usa o idioma do app.
    var displayName: String { id == SoundScene.restID ? String(localized: "Resto do sistema") : name }
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

/// Estado do rastreio da cabeça. É um tipo (e não um texto) para a cor e o ícone não dependerem do idioma.
enum HeadStatus: Equatable {
    case off, waitingForPermission, startingCamera, calibrating, following, noFace
    case pausedNoSound, permissionError, cameraError, switchingCamera, recalibrated

    var text: String {
        switch self {
        case .off: String(localized: "Rastreio desligado")
        case .waitingForPermission: String(localized: "Responda ao pedido de acesso à câmera")
        case .startingCamera: String(localized: "Ligando a câmera…")
        case .calibrating: String(localized: "Olhe para a tela por 2 s (calibrando)")
        case .following: String(localized: "Acompanhando a cabeça")
        case .noFace: String(localized: "Rosto não encontrado")
        case .pausedNoSound: String(localized: "Câmera pausada: sem som tocando")
        case .permissionError: String(localized: "Erro: permissão da câmera")
        case .cameraError: String(localized: "Erro: câmera indisponível")
        case .switchingCamera: String(localized: "Trocando de câmera…")
        case .recalibrated: String(localized: "Centro recalibrado")
        }
    }

    var isError: Bool { self == .permissionError || self == .cameraError }

    /// Símbolo e cor semântica (laranja = atenção, vermelho = erro, verde = tudo certo).
    var style: (symbol: String, color: Color) {
        switch self {
        case .permissionError, .cameraError: ("exclamationmark.triangle.fill", .red)
        case .noFace: ("person.fill.questionmark", .orange)
        case .pausedNoSound: ("pause.circle.fill", .orange)
        case .following, .recalibrated: ("checkmark.circle.fill", .green)
        default: ("circle.dotted", .secondary)
        }
    }
}

/// Estado da câmera/rastreio com símbolo e cor no ícone; o texto fica em cinza para manter o contraste.
struct StatusLabel: View {
    let status: HeadStatus

    var body: some View {
        Label {
            Text(status.text).foregroundStyle(.secondary)
        } icon: {
            Image(systemName: status.style.symbol).foregroundStyle(status.style.color)
        }
        .labelStyle(.titleAndIcon)
    }
}

/// Linha de menu com destaque ao passar o mouse e ao receber foco do teclado, como um item de menu nativo.
struct MenuRow: View {
    let label: Text
    var shortcut: String?
    var checked = false
    let action: () -> Void
    @State private var hovering = false
    @FocusState private var focused: Bool

    /// Texto traduzível (itens fixos do menu).
    init(title: LocalizedStringKey, shortcut: String? = nil, checked: Bool = false, action: @escaping () -> Void) {
        label = Text(title); self.shortcut = shortcut; self.checked = checked; self.action = action
    }

    /// Texto exato, sem tradução (nomes de perfis escritos pela pessoa).
    init(verbatim title: String, shortcut: String? = nil, checked: Bool = false, action: @escaping () -> Void) {
        label = Text(verbatim: title); self.shortcut = shortcut; self.checked = checked; self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack {
                label
                Spacer()
                if checked { Image(systemName: "checkmark").foregroundStyle(Color.accentColor) }
                if let shortcut { Text(shortcut).foregroundStyle(.secondary) }
            }
            .padding(.horizontal, Space.s).padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(hovering || focused ? Color.accentColor.opacity(0.18) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($focused)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(checked ? .isSelected : [])
    }
}

/// Idioma da interface: acompanha o sistema, ou fica fixo em português ou inglês (vale depois de reabrir o app).
enum AppLanguage: String, CaseIterable {
    case system, pt, en

    /// O que a pessoa escolheu (guardado nas preferências do app).
    static var current: AppLanguage {
        let stored = UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "")?["AppleLanguages"] as? [String]
        guard let first = stored?.first else { return .system }
        return first.hasPrefix("pt") ? .pt : (first.hasPrefix("en") ? .en : .system)
    }

    /// O idioma com que o app está rodando agora (decidido na abertura).
    static let running: AppLanguage = current

    static func apply(_ language: AppLanguage) {
        switch language {
        case .system: UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        case .pt: UserDefaults.standard.set(["pt"], forKey: "AppleLanguages")
        case .en: UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
        }
    }

    /// Abre uma nova instância (1 s depois, para a atual terminar e devolver o som) e fecha esta.
    @MainActor static func relaunch() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 1; /usr/bin/open -n \"$0\"", Bundle.main.bundleURL.path]
        try? task.run()
        NSApp.terminate(nil)
    }
}
