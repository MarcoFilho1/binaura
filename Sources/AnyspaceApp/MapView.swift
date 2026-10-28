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
                    Circle().fill(Color.accentColor.opacity(0.9)).frame(width: 26, height: 26)
                    Image(systemName: "arrowtriangle.up.fill").font(.system(size: 11)).foregroundStyle(.white)
                        .offset(y: -1)
                }
                .rotationEffect(.degrees(Double(model.headAngle)))
                .position(center)

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
