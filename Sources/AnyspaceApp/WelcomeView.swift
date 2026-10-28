import SwiftUI

/// Primeira execução: o que o app faz, o que ele vai pedir e como desfazer.
struct WelcomeView: View {
    let done: () -> Void

    var body: some View {
        VStack(spacing: Space.xl) {
            VStack(spacing: Space.s) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 52)).foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text("Bem-vindo ao Anyspace").font(.title.weight(.semibold))
                Text("Coloque cada app em um lugar ao seu redor, com o fone que você já tem.")
                    .font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: Space.l) {
                step("headphones", "Use fones de ouvido", "O efeito foi feito para fones. Nos alto-falantes do Mac ele quase não aparece.")
                step("waveform", "Permita a captura de áudio", "O macOS vai pedir. O Anyspace precisa ouvir o som dos apps para posicioná-lo e silencia o original enquanto está ligado.")
                step("camera", "A câmera é opcional", "Se quiser que o espaço fique parado quando você vira a cabeça, ligue “Acompanhar a cabeça”. Ela só funciona com som tocando.")
                step("power", "Desligar devolve o som normal", "O interruptor no topo da janela e na barra de menu desfaz tudo na hora.")
            }
            Button("Ligar e começar", action: done)
                .buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut(.defaultAction)
        }
        .padding(Space.xl * 1.5)
        .frame(width: 460)
    }

    private func step(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Space.l) {
            Image(systemName: symbol).font(.title2).foregroundStyle(Color.accentColor)
                .frame(width: 30).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
