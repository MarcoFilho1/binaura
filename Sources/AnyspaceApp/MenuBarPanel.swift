import AnyspaceCore
import AppKit
import SwiftUI

/// Painel da barra de menu: o uso do dia a dia. Liga e desliga, troca de perfil e ajusta o volume de cada fonte.
struct MenuBarPanel: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            header
            if model.effectOn {
                if model.scene.headTracking {
                    Label(model.headStatus, systemImage: "person.fill.viewfinder")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                if !model.scene.profiles.isEmpty { profiles }
                sources
            } else {
                Text("O som do Mac sai normalmente.").font(.callout).foregroundStyle(.secondary)
            }
            Divider()
            footer
        }
        .padding(Space.l)
        .frame(width: 300)
    }

    private var header: some View {
        HStack(spacing: Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Anyspace").font(.headline)
                Text(statusLine).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Toggle("Efeito espacial", isOn: Binding(get: { model.effectOn }, set: { model.setEffect($0) }))
                .toggleStyle(.switch).labelsHidden()
        }
    }

    private var statusLine: String {
        model.effectOn ? model.outputName : "Desligado"
    }

    private var profiles: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Perfil").font(.caption).foregroundStyle(.secondary)
            ForEach(model.scene.profiles) { profile in
                Button { model.applyProfile(profile.name) } label: {
                    HStack {
                        Image(systemName: "checkmark").opacity(model.activeProfileName == profile.name ? 1 : 0)
                            .frame(width: 16)
                        Text(profile.name)
                        Spacer()
                    }
                    .padding(.vertical, 3).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var sources: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("Volume").font(.caption).foregroundStyle(.secondary)
            ForEach(model.scene.all) { source in
                HStack(spacing: Space.s) {
                    SourceIconView(id: source.id, size: 24)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(source.name).font(.callout).lineLimit(1)
                        Slider(value: Binding(get: { source.volume }, set: { v in model.update(source.id) { $0.volume = v } }), in: 0...1)
                            .controlSize(.small).disabled(source.muted)
                            .accessibilityLabel("Volume de \(source.name)")
                    }
                    Button { model.update(source.id) { $0.muted.toggle() } } label: {
                        Image(systemName: source.muted ? "speaker.slash.fill" : "speaker.wave.2.fill").frame(width: 18)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(source.muted ? "Reativar \(source.name)" : "Silenciar \(source.name)")
                }
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button("Abrir Anyspace…") {
                openWindow(id: "main")
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("o")
            Button("Sair do Anyspace") {
                model.shutdown()
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .buttonStyle(.plain)
    }
}
