import AppKit
import SwiftUI

/// Ponto de entrada. Com `--snapshot PASTA` o app só gera capturas da interface com dados de exemplo e sai.
@main
enum Launcher {
    static func main() {
        if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), CommandLine.arguments.count > i + 1 {
            MainActor.assumeIsolated { Snapshot.run(into: CommandLine.arguments[i + 1]) }
        } else if let i = CommandLine.arguments.firstIndex(of: "--show"), CommandLine.arguments.count > i + 1 {
            let dark = CommandLine.arguments.contains("--dark")
            MainActor.assumeIsolated { Snapshot.show(name: CommandLine.arguments[i + 1], seconds: 12, dark: dark) }
        } else {
            BinauraApp.main()
        }
    }
}

struct BinauraApp: App {
    @StateObject private var model = AppModel(startEffect: !CommandLine.arguments.contains("--no-start") && UserDefaults.standard.bool(forKey: "didSeeWelcome"))

    var body: some Scene {
        Window("Binaura", id: "main") {
            MainWindowView()
                .environmentObject(model)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    model.shutdown()
                }
        }
        .defaultSize(width: 1080, height: 700)
        .windowToolbarStyle(.unified)

        Window("Câmera (debug)", id: "camera") {
            CameraDebugView().environmentObject(model)
        }
        .defaultSize(width: 480, height: 680)

        MenuBarExtra {
            MenuBarPanel().environmentObject(model)
        } label: {
            Image(systemName: model.message != nil && !model.effectOn ? "exclamationmark.triangle.fill"
                  : (model.effectOn ? "waveform.circle.fill" : "waveform.circle"))
                .accessibilityLabel("Binaura, efeito \(model.effectOn ? "ligado" : "desligado")\(model.message != nil ? ", com aviso" : "")")
        }
        .menuBarExtraStyle(.window)
    }
}
