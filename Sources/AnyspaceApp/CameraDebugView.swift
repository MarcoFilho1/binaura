import AVFoundation
import AppKit
import SwiftUI

/// Janela de depuração: imagem da câmera (como espelho), retângulo do rosto, ângulo bruto e filtrado.
struct CameraDebugView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                CameraPreview(session: model.previewSession)
                GeometryReader { geo in
                    if let box = model.faceBox {
                        // A imagem é mostrada espelhada, então o x inverte.
                        Rectangle()
                            .stroke(Color.green, lineWidth: 2)
                            .frame(width: box.width * geo.size.width, height: box.height * geo.size.height)
                            .position(x: (1 - box.midX) * geo.size.width, y: (1 - box.midY) * geo.size.height)
                    }
                }
            }
            .aspectRatio(4 / 3, contentMode: .fit)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                if model.previewSession == nil { Text("Ligando a câmera…").foregroundStyle(.white) }
            }

            AngleGauge(raw: model.headRaw, filtered: model.headAngle)

            HStack {
                Button("Calibrar centro (olhe para a tela)") { model.calibrate() }
                Text(model.headStatus).font(.caption).foregroundStyle(.secondary)
            }
            Picker("Câmera", selection: $model.scene.cameraName) {
                Text("Do Mac (padrão)").tag("")
                ForEach(model.cameras, id: \.self) { Text($0).tag($0) }
            }
            Toggle("Inverter o sentido", isOn: $model.scene.invertHead)
            Text("Vire a cabeça para a direita: o ângulo deve ficar positivo e o retângulo verde deve acompanhar o rosto. Esta janela não gira o som; para isso ligue “Acompanhar a cabeça”.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .frame(minWidth: 460, minHeight: 560)
        .onAppear { model.debugCameraOpen = true }
        .onDisappear { model.debugCameraOpen = false }
    }
}

/// Barra de -90° a +90° com o ângulo filtrado (usado no som) e o bruto (medido pela câmera).
struct AngleGauge: View {
    let raw: Float?
    let filtered: Float

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(String(format: "Filtrado %+.0f°", filtered)).monospacedDigit().bold()
                Spacer()
                Text(raw.map { String(format: "Bruto da câmera %+.0f°", $0) } ?? "Sem rosto").monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.2))
                    Rectangle().fill(Color.secondary.opacity(0.5)).frame(width: 1).position(x: geo.size.width / 2, y: geo.size.height / 2)
                    Circle().fill(Color.accentColor).frame(width: 14, height: 14)
                        .position(x: geo.size.width * (0.5 + CGFloat(max(-90, min(90, filtered))) / 180), y: geo.size.height / 2)
                }
            }
            .frame(height: 16)
            HStack { Text("← esquerda").font(.caption2); Spacer(); Text("direita →").font(.caption2) }
                .foregroundStyle(.secondary)
        }
    }
}

struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession?

    func makeNSView(context: Context) -> PreviewView { PreviewView() }

    func updateNSView(_ view: PreviewView, context: Context) {
        if view.previewLayer.session !== session { view.previewLayer.session = session }
    }

    final class PreviewView: NSView {
        let previewLayer = AVCaptureVideoPreviewLayer()
        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            previewLayer.videoGravity = .resizeAspect
            previewLayer.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1)) // espelho
            layer?.addSublayer(previewLayer)
        }
        required init?(coder: NSCoder) { fatalError() }
        override func layout() { super.layout(); previewLayer.frame = bounds }
    }
}
