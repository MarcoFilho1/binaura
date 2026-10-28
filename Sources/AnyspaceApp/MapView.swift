import AnyspaceCore
import SwiftUI

/// Mapa visto de cima: você no centro olhando para cima. Arraste as fontes para mudar de onde o som vem.
struct MapView: View {
    @EnvironmentObject var model: AppModel
    private let metersPerRadius = 4.0

    var body: some View {
        GeometryReader { geo in
            let radius = max(40, min(geo.size.width, geo.size.height) / 2 - 28)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ZStack {
                ForEach(1...4, id: \.self) { meter in
                    let r = radius * CGFloat(meter) / CGFloat(metersPerRadius)
                    Circle()
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                        .frame(width: r * 2, height: r * 2)
                        .position(center)
                    Text("\(meter) m")
                        .font(.caption2).foregroundStyle(.secondary)
                        .position(x: center.x + 4 + 14, y: center.y - r + 8)
                }
                Text("frente").font(.caption).foregroundStyle(.secondary)
                    .position(x: center.x, y: center.y - radius - 14)

                // Você: o triângulo gira com a cabeça.
                ZStack {
                    ViewCone().fill(LinearGradient(colors: [Color.accentColor.opacity(0.55), .clear],
                                                   startPoint: .center, endPoint: .top))
                        .frame(width: 120, height: 120)
                    Circle().fill(Color.accentColor).frame(width: 22, height: 22)
                    Capsule().fill(.white).frame(width: 4, height: 11).offset(y: -4)
                }
                .rotationEffect(.degrees(Double(model.headAngle)))
                .animation(.linear(duration: 0.1), value: model.headAngle)
                .position(center)
                Text(String(format: "%+.0f°", model.headAngle))
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    .position(x: center.x, y: center.y + 26)

                // Abertura do estéreo: onde ficam os alto-falantes virtuais (E e D) de cada fonte.
                ForEach(model.scene.all) { source in
                    StereoSpread(source: source, width: model.scene.width,
                                 center: center, radius: radius, metersPerRadius: metersPerRadius)
                }

                ForEach(model.scene.all) { source in
                    SourceDot(source: source,
                              center: center, radius: radius, metersPerRadius: metersPerRadius)
                }
            }
            .coordinateSpace(name: "map")
        }
        .frame(minWidth: 380, minHeight: 380)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct SourceDot: View {
    @EnvironmentObject var model: AppModel
    let source: SourceSetting
    let center: CGPoint
    let radius: CGFloat
    let metersPerRadius: Double

    var body: some View {
        let p = MapGeometry.point(angle: source.angle, distance: source.distance,
                                  metersPerRadius: metersPerRadius, radiusPixels: Double(radius))
        VStack(spacing: 2) {
            ZStack {
                Circle().fill(source.muted ? Color.gray : (source.id == SoundScene.restID ? Color.orange : Color.green))
                    .frame(width: 30, height: 30)
                Text(String(source.name.prefix(1))).font(.headline).foregroundStyle(.white)
            }
            Text(source.name).font(.caption2).lineLimit(1)
        }
        .position(x: center.x + p.dx, y: center.y + p.dy + 8)
        .gesture(
            DragGesture(coordinateSpace: .named("map"))
                .onChanged { value in
                    let polar = MapGeometry.polar(dx: Double(value.location.x - center.x),
                                                  dy: Double(value.location.y - center.y - 8),
                                                  metersPerRadius: metersPerRadius, radiusPixels: Double(radius))
                    model.move(source.id, angle: polar.angle, distance: polar.distance)
                }
        )
        .help("\(source.name): \(Int(source.angle))° a \(String(format: "%.1f", source.distance)) m")
    }
}

/// Cone de visão: aponta para cima e abre 70°.
private struct ViewCone: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        p.move(to: c)
        p.addArc(center: c, radius: rect.width / 2, startAngle: .degrees(-125), endAngle: .degrees(-55), clockwise: false)
        p.closeSubpath()
        return p
    }
}

private struct StereoSpread: View {
    let source: SourceSetting
    let width: Float
    let center: CGPoint
    let radius: CGFloat
    let metersPerRadius: Double

    var body: some View {
        let l = MapGeometry.point(angle: source.angle - width, distance: source.distance,
                                  metersPerRadius: metersPerRadius, radiusPixels: Double(radius))
        let r = MapGeometry.point(angle: source.angle + width, distance: source.distance,
                                  metersPerRadius: metersPerRadius, radiusPixels: Double(radius))
        let pl = CGPoint(x: center.x + l.dx, y: center.y + l.dy + 8)
        let pr = CGPoint(x: center.x + r.dx, y: center.y + r.dy + 8)
        let tint: Color = source.muted ? .gray : (source.id == SoundScene.restID ? .orange : .green)
        ZStack {
            Path { p in p.move(to: pl); p.addLine(to: pr) }
                .stroke(tint.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            speaker("E", at: pl, tint: tint)
            speaker("D", at: pr, tint: tint)
        }
        .allowsHitTesting(false)
    }

    private func speaker(_ letter: String, at point: CGPoint, tint: Color) -> some View {
        ZStack {
            Circle().fill(tint.opacity(0.35)).frame(width: 16, height: 16)
            Text(letter).font(.system(size: 9, weight: .bold)).foregroundStyle(tint)
        }
        .position(point)
    }
}
