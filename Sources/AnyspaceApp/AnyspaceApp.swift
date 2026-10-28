import SwiftUI

@main
struct AnyspaceApp: App {
    @StateObject private var model = AppModel(startEffect: !CommandLine.arguments.contains("--no-start"))

    var body: some Scene {
        Window("Anyspace", id: "main") {
            HStack(spacing: 0) {
                MapView().padding()
                Divider()
                ControlsView().frame(width: 360)
            }
            .environmentObject(model)
            .frame(minWidth: 820, minHeight: 560)
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                model.shutdown()
            }
        }

        Window("Câmera (debug)", id: "camera") {
            CameraDebugView().environmentObject(model)
        }

        MenuBarExtra("Anyspace", systemImage: model.effectOn ? "waveform.circle.fill" : "waveform.circle") {
            Toggle("Efeito espacial", isOn: Binding(get: { model.effectOn }, set: { model.setEffect($0) }))
            Divider()
            OpenWindowButton()
            Button("Sair") { model.shutdown(); NSApplication.shared.terminate(nil) }
        }
    }
}

private struct OpenWindowButton: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("Abrir janela") {
            openWindow(id: "main")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
}
