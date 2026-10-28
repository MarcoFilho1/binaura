import AVFoundation
import BinauraCore
import AppKit
import SwiftUI

/// Janela de depuração: imagem da câmera (como espelho), retângulo do rosto, ângulo bruto e filtrado.
struct CameraDebugView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Form {
            Section {
                ZStack {
                    CameraPreview(session: model.previewSession)
                    FaceOverlay(detail: model.faceDetail)
                    GeometryReader { geo in
                        if let box = model.faceBox {
                            // A imagem é mostrada espelhada, então o x inverte.
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.green, lineWidth: 2)
                                .frame(width: box.width * geo.size.width, height: box.height * geo.size.height)
                                .position(x: (1 - box.midX) * geo.size.width, y: (1 - box.midY) * geo.size.height)
                        }
                    }
                    if model.previewSession == nil {
                        VStack(spacing: Space.s) {
                            if model.headStatus.hasPrefix("Erro") || model.message != nil {
                                Image(systemName: "video.slash.fill").font(.title).foregroundStyle(.white.opacity(0.8))
                                Text(model.message ?? model.headStatus).font(.callout)
                                    .foregroundStyle(.white.opacity(0.9)).multilineTextAlignment(.center)
                                if model.permissionIssue == .camera {
                                    Button("Abrir Ajustes…") { NSWorkspace.shared.open(PermissionIssue.camera.settingsURL) }
                                }
                            } else {
                                ProgressView().controlSize(.small)
                                Text("Ligando a câmera…").font(.callout).foregroundStyle(.white.opacity(0.8))
                            }
                        }
                        .padding(Space.l)
                    }
                }
                .aspectRatio(4 / 3, contentMode: .fit)
                .background(Color.black)
                .accessibilityLabel("Imagem da câmera")
                .listRowInsets(EdgeInsets())

                AngleGauge(raw: model.headRaw, filtered: model.headAngle)
            }

            Section {
                GazeScreen(detail: model.faceDetail)
                    .listRowInsets(EdgeInsets(top: Space.m, leading: Space.l, bottom: Space.m, trailing: Space.l))
                if let d = model.faceDetail {
                    LabeledContent("Cabeça") {
                        Text(poseText(yaw: d.yaw, pitch: d.pitch)).monospacedDigit().foregroundStyle(.secondary)
                    }
                    if let gy = d.gazeYaw, let gp = d.gazePitch {
                        LabeledContent("Olhar (estimado)") {
                            Text(poseText(yaw: gy, pitch: gp)).monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Para onde você olha")
            } footer: {
                Text("Estimativa sem calibração: soma a direção da cabeça com a posição da pupila no olho. Serve para comparar, não para medir com precisão. Se a seta vertical estiver ao contrário, me avise.")
            }

            Section {
                Picker("Câmera", selection: $model.scene.cameraName) {
                    Text("Do Mac (padrão)").tag("")
                    ForEach(model.cameras, id: \.self) { Text($0).tag($0) }
                }
                Toggle("Inverter o sentido", isOn: $model.scene.invertHead)
                LabeledContent("Estado") { StatusLabel(text: model.headStatus) }
                Button("Calibrar centro") { model.calibrate() }
            } footer: {
                Text("Olhe para a tela e clique em “Calibrar centro”. Vire a cabeça para a direita: o ângulo deve ficar positivo e o retângulo verde deve acompanhar o rosto. Esta janela não gira o som; para isso ligue “Acompanhar a cabeça”.")
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 460, minHeight: 640)
        .onAppear { model.debugCameraOpen = true }
        .onDisappear { model.debugCameraOpen = false }
    }
}

private func poseText(yaw: Float, pitch: Float?) -> String {
    let horizontal = abs(yaw) < 1 ? "centro" : String(format: "%.0f° %@", abs(yaw), yaw > 0 ? "direita" : "esquerda")
    guard let pitch else { return horizontal }
    let vertical = abs(pitch) < 1 ? "" : String(format: " · %.0f° %@", abs(pitch), pitch > 0 ? "cima" : "baixo")
    return horizontal + vertical
}

/// Contornos do rosto, pupilas e a seta do olhar, sobre a imagem espelhada da câmera.
struct FaceOverlay: View {
    let detail: FaceDetail?

    var body: some View {
        Canvas { ctx, size in
            guard let d = detail else { return }
            // A imagem é mostrada espelhada, então o x inverte.
            func point(_ p: CGPoint) -> CGPoint { CGPoint(x: (1 - p.x) * size.width, y: (1 - p.y) * size.height) }
            for contour in d.contours {
                var path = Path()
                for (i, p) in contour.points.enumerated() { i == 0 ? path.move(to: point(p)) : path.addLine(to: point(p)) }
                if contour.closed { path.closeSubpath() }
                ctx.stroke(path, with: .color(.green.opacity(0.9)), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            }
            for pupil in d.pupils {
                let c = point(pupil)
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - 3, y: c.y - 3, width: 6, height: 6)), with: .color(.cyan))
            }
            // Seta do olhar a partir do ponto médio das pupilas (ou do centro do rosto).
            if let gy = d.gazeYaw, let gp = d.gazePitch {
                let origin = d.pupils.isEmpty ? point(CGPoint(x: d.box.midX, y: d.box.midY))
                    : point(CGPoint(x: d.pupils.map(\.x).reduce(0, +) / CGFloat(d.pupils.count),
                                    y: d.pupils.map(\.y).reduce(0, +) / CGFloat(d.pupils.count)))
                let target = CGPoint(x: origin.x + CGFloat(max(-45, min(45, gy))) * 2.2,
                                     y: origin.y - CGFloat(max(-30, min(30, gp))) * 2.2)
                var arrow = Path()
                arrow.move(to: origin); arrow.addLine(to: target)
                ctx.stroke(arrow, with: .color(.yellow), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                ctx.fill(Path(ellipseIn: CGRect(x: target.x - 5, y: target.y - 5, width: 10, height: 10)), with: .color(.yellow))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Uma tela em miniatura com um ponto onde a pessoa parece olhar.
struct GazeScreen: View {
    let detail: FaceDetail?

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.quaternary)
                RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.separator)
                Path { p in
                    p.move(to: CGPoint(x: w / 2, y: 6)); p.addLine(to: CGPoint(x: w / 2, y: h - 6))
                    p.move(to: CGPoint(x: 6, y: h / 2)); p.addLine(to: CGPoint(x: w - 6, y: h / 2))
                }.stroke(.tertiary, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                if let d = detail, let gy = d.gazeYaw, let gp = d.gazePitch {
                    let s = screenPoint(gazeYaw: gy, gazePitch: gp)
                    Circle().fill(Color.accentColor).frame(width: 16, height: 16)
                        .overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 2))
                        .shadow(radius: 3, y: 1)
                        .position(x: w / 2 + CGFloat(s.x) * (w / 2 - 12), y: h / 2 - CGFloat(s.y) * (h / 2 - 12))
                        .animation(.smooth(duration: 0.15), value: s.x)
                        .animation(.smooth(duration: 0.15), value: s.y)
                } else {
                    Text("Sem rosto").font(.callout).foregroundStyle(.secondary)
                }
            }
        }
        .frame(height: 112)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tela em miniatura com o ponto estimado do olhar")
    }
}

/// Barra de -90° a +90° com o ângulo filtrado (usado no som) e o bruto (medido pela câmera).
struct AngleGauge: View {
    let raw: Float?
    let filtered: Float

    var body: some View {
        VStack(spacing: Space.xs) {
            HStack {
                Text(String(format: "Filtrado %+.0f°", filtered)).monospacedDigit().fontWeight(.semibold)
                Spacer()
                Text(raw.map { String(format: "Bruto da câmera %+.0f°", $0) } ?? "Sem rosto")
                    .monospacedDigit().foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Rectangle().fill(.tertiary).frame(width: 1).position(x: geo.size.width / 2, y: geo.size.height / 2)
                    Circle().fill(Color.accentColor).frame(width: 14, height: 14)
                        .position(x: geo.size.width * (0.5 + CGFloat(max(-90, min(90, filtered))) / 180), y: geo.size.height / 2)
                }
            }
            .frame(height: 16)
            HStack {
                Label("esquerda", systemImage: "arrow.left"); Spacer(); Label("direita", systemImage: "arrow.right")
            }
            .labelStyle(.titleAndIcon).font(.caption2).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ângulo da cabeça")
        .accessibilityValue(String(format: "%@ filtrado", Describe.angle(filtered)))
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
