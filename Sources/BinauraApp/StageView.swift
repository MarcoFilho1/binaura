import BinauraCore
import SwiftUI

/// O palco: o espaço visto de cima, com você no centro olhando para cima. Arraste as fontes,
/// ou selecione uma e use as setas do teclado (esquerda/direita giram; cima/baixo afastam).
struct StageView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focused: Bool
    private let metersPerRadius = 4.0

    var body: some View {
        GeometryReader { geo in
            // Reserva espaço para o aviso (em cima) e a faixa de "desligado" (embaixo), para nada cobrir o mapa,
            // e margem lateral para os rótulos Esquerda/Direita.
            let top: CGFloat = model.message == nil ? 0 : (model.permissionIssue == nil ? 64 : 84)
            let bottom: CGFloat = 108   // fixo: ligar/desligar não muda o tamanho do mapa
            let radius = max(80, min(geo.size.width / 2 - 84, (geo.size.height - top - bottom) / 2 - 40))
            let center = CGPoint(x: geo.size.width / 2, y: top + (geo.size.height - top - bottom) / 2 + 6)
            ZStack {
                Grid2D(center: center, radius: radius, metersPerRadius: metersPerRadius)

                ForEach(model.scene.all) { source in
                    SpreadArc(source: source, width: model.scene.width, center: center,
                              radius: radius, metersPerRadius: metersPerRadius,
                              selected: source.id == model.selectedID)
                }

                HeadMarker(center: center)

                ForEach(model.scene.all) { source in
                    SourceDisc(source: source, center: center, radius: radius, metersPerRadius: metersPerRadius,
                               stageFocused: focused, onSelect: { focused = true })
                }
                .opacity(model.effectOn ? 1 : 0.5)
            }
            .coordinateSpace(name: "stage")
            .overlay(alignment: .top) { notice.padding([.horizontal, .top], Space.l) }
            .overlay(alignment: .bottom) {
                if model.effectOn {
                    Text(LocalizedStringKey(focused ? "Setas: esquerda e direita giram a fonte, cima e baixo a aproximam ou afastam."
                                 : "Arraste uma fonte para mudar de lugar, ou selecione e use as setas do teclado."))
                        .font(.system(size: 12)).foregroundStyle(focused ? Color.primary : Color.secondary)
                        .padding(.bottom, Space.l)
                } else {
                    OffState().padding(Space.l)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { focused = true }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onChange(of: model.stageFocusRequest) { _, _ in focused = true }
        .onKeyPress(.leftArrow) { nudge(angle: -5) }
        .onKeyPress(.rightArrow) { nudge(angle: 5) }
        .onKeyPress(.upArrow) { nudge(distance: -0.25) }
        .onKeyPress(.downArrow) { nudge(distance: 0.25) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mapa do som ao seu redor")
    }

    private func nudge(angle: Float = 0, distance: Float = 0) -> KeyPress.Result {
        guard let id = model.selectedID else { return .ignored }
        model.nudge(id, angle: angle, distance: distance)
        return .handled
    }

    @ViewBuilder private var notice: some View {
        if let message = model.message {
            HStack(spacing: Space.m) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(message).font(.callout).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Space.s)
                if let issue = model.permissionIssue {
                    Button("Abrir Ajustes…") { NSWorkspace.shared.open(issue.settingsURL) }
                }
                Button { model.message = nil } label: { Image(systemName: "xmark") }
                    .buttonStyle(.borderless).help("Dispensar").accessibilityLabel("Dispensar aviso")
            }
            .padding(Space.m)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Space.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Space.radius, style: .continuous).strokeBorder(.separator))
            .frame(maxWidth: 560)
        }
    }
}

// MARK: grade

/// Anéis de 1 a 4 m, eixos e marcas de 30°. Desenhado em Canvas para ficar nítido em qualquer escala.
private struct Grid2D: View {
    let center: CGPoint
    let radius: CGFloat
    let metersPerRadius: Double

    var body: some View {
        ZStack {
            Canvas { ctx, _ in
                // Vinheta suave: o palco ganha um pouco de profundidade ao centro.
                let outer = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                ctx.fill(Path(ellipseIn: outer),
                         with: .radialGradient(Gradient(colors: [.primary.opacity(0.045), .clear]),
                                               center: center, startRadius: 0, endRadius: radius))
                for meter in 1...4 {
                    let r = radius * CGFloat(meter) / CGFloat(metersPerRadius)
                    let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                    ctx.stroke(Path(ellipseIn: rect), with: .color(.primary.opacity(meter == 4 ? 0.16 : 0.08)), lineWidth: 1)
                }
                var axes = Path()
                for angle in [0.0, 90, 180, 270] {
                    let p = MapGeometry.point(angle: Float(angle), distance: 4, metersPerRadius: metersPerRadius, radiusPixels: Double(radius))
                    axes.move(to: center)
                    axes.addLine(to: CGPoint(x: center.x + p.dx, y: center.y + p.dy))
                }
                ctx.stroke(axes, with: .color(.primary.opacity(0.06)), lineWidth: 1)
                var ticks = Path()
                for step in 0..<12 {
                    let angle = Float(step * 30)
                    let outer = MapGeometry.point(angle: angle, distance: 4, metersPerRadius: metersPerRadius, radiusPixels: Double(radius))
                    let inner = MapGeometry.point(angle: angle, distance: 3.85, metersPerRadius: metersPerRadius, radiusPixels: Double(radius))
                    ticks.move(to: CGPoint(x: center.x + inner.dx, y: center.y + inner.dy))
                    ticks.addLine(to: CGPoint(x: center.x + outer.dx, y: center.y + outer.dy))
                }
                ctx.stroke(ticks, with: .color(.primary.opacity(0.18)), lineWidth: 1)
            }
            .accessibilityHidden(true)

            ForEach(1...4, id: \.self) { meter in
                let r = radius * CGFloat(meter) / CGFloat(metersPerRadius)
                let spot = MapGeometry.point(angle: 135, distance: Float(meter), metersPerRadius: metersPerRadius, radiusPixels: Double(radius))
                Text("\(meter) m")
                    .font(.system(size: 11).monospacedDigit()).foregroundStyle(.secondary)
                    .padding(.horizontal, 3)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .position(x: center.x + spot.dx, y: center.y + spot.dy)
                    .accessibilityHidden(true)
            }
            Group {
                Text("Frente").position(x: center.x, y: center.y - radius - 16)
                Text("Trás").position(x: center.x, y: center.y + radius + 16)
                Text("Esquerda").position(x: center.x - radius - 34, y: center.y)
                Text("Direita").position(x: center.x + radius + 30, y: center.y)
            }
            .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            .accessibilityHidden(true)
        }
    }
}

// MARK: você

private struct HeadMarker: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let center: CGPoint

    var body: some View {
        let tracking = model.effectOn && model.scene.headTracking
        ZStack {
            ViewCone()
                .fill(LinearGradient(colors: [Color.accentColor.opacity(tracking ? 0.30 : 0.14), .clear],
                                     startPoint: .center, endPoint: .top))
                .frame(width: 150, height: 150)
            Circle().fill(.background).frame(width: 30, height: 30)
                .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: 2))
                .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
            Image(systemName: "arrowtriangle.up.fill").font(.system(size: 9)).foregroundStyle(Color.accentColor)
        }
        .rotationEffect(.degrees(Double(model.headAngle)))
        .animation(reduceMotion ? nil : .smooth(duration: 0.12), value: model.headAngle)
        .position(center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Você")
        .accessibilityValue(tracking ? String(localized: "Cabeça virada \(Describe.angle(model.headAngle))") : String(localized: "Olhando para a frente"))

        if tracking {
            Text(String(format: "%+.0f°", model.headAngle))
                .font(.system(size: 11).monospacedDigit())
                .padding(.horizontal, Space.s).padding(.vertical, 2)
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.separator))
                .position(x: center.x, y: center.y + 34)
                .accessibilityHidden(true)
        }
    }
}

/// Cone de visão: aponta para cima e abre 70°.
private struct ViewCone: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        p.move(to: c)
        for step in 0...14 {
            let angle = (-125.0 + Double(step) * 70.0 / 14.0) * .pi / 180
            p.addLine(to: CGPoint(x: c.x + cos(angle) * rect.width / 2, y: c.y + sin(angle) * rect.width / 2))
        }
        p.closeSubpath()
        return p
    }
}

// MARK: fontes

/// Onde ficam os dois alto-falantes virtuais da fonte (esquerdo e direito).
private struct SpreadArc: View {
    let source: SourceSetting
    let width: Float
    let center: CGPoint
    let radius: CGFloat
    let metersPerRadius: Double
    let selected: Bool

    var body: some View {
        let points = (0...10).map { i -> CGPoint in
            let angle = source.angle - width + 2 * width * Float(i) / 10
            let p = MapGeometry.point(angle: angle, distance: source.distance, metersPerRadius: metersPerRadius, radiusPixels: Double(radius))
            return CGPoint(x: center.x + p.dx, y: center.y + p.dy)
        }
        let tint: Color = selected ? .accentColor : .secondary
        ZStack {
            Path { p in
                p.move(to: points[0])
                for point in points.dropFirst() { p.addLine(to: point) }
            }
            .stroke(tint.opacity(selected ? 0.55 : 0.28), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            ForEach([0, 10], id: \.self) { i in
                Circle().fill(tint.opacity(selected ? 0.9 : 0.45)).frame(width: 6, height: 6).position(points[i])
            }
        }
        .opacity(source.muted ? 0.35 : 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct SourceDisc: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let source: SourceSetting
    let center: CGPoint
    let radius: CGFloat
    let metersPerRadius: Double
    var stageFocused = false
    var onSelect: () -> Void = {}

    var body: some View {
        let p = MapGeometry.point(angle: source.angle, distance: source.distance,
                                  metersPerRadius: metersPerRadius, radiusPixels: Double(radius))
        let selected = model.selectedID == source.id
        let level = CGFloat(min(1, (model.levels[source.id] ?? 0) * 3))
        VStack(spacing: Space.xs) {
            ZStack {
                Circle().fill(.background).frame(width: 48, height: 48)
                    .shadow(color: .black.opacity(0.22), radius: 6, y: 2)
                if !source.muted {
                    // O anel fica fora do disco (60 pt). Com "reduzir movimento" só muda de opacidade, sem escala.
                    Circle().stroke(Color.accentColor.opacity(0.55), lineWidth: 2.5)
                        .frame(width: 60, height: 60)
                        .scaleEffect(reduceMotion ? 1 : 1 + level * 0.25)
                        .opacity(Double(level))
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: level)
                }
                SourceIconView(id: source.id, size: 36)
                    .grayscale(source.muted ? 1 : 0)
                    .opacity(source.muted ? 0.55 : 1)
                if selected {
                    Circle().strokeBorder(Color.accentColor, lineWidth: 2.5).frame(width: 52, height: 52)
                    // Foco do teclado: um segundo aro fino em volta da fonte que as setas vão mover.
                    if stageFocused {
                        Circle().strokeBorder(Color.accentColor.opacity(0.45), lineWidth: 1.5).frame(width: 58, height: 58)
                    }
                }
                if source.muted {
                    Image(systemName: "speaker.slash.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                        .padding(4).background(Color.secondary, in: Circle()).offset(x: 17, y: 17)
                }
            }
            Text(source.displayName)
                .font(.system(size: 11, weight: selected ? .semibold : .regular))
                .lineLimit(1)
                .padding(.horizontal, Space.s).padding(.vertical, 2)
                .background(selected ? AnyShapeStyle(Color.accentColor.opacity(0.9)) : AnyShapeStyle(.regularMaterial), in: Capsule())
                .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .position(x: center.x + p.dx, y: center.y + p.dy + 10)
        .gesture(
            DragGesture(minimumDistance: 2, coordinateSpace: .named("stage"))
                .onChanged { value in
                    model.selectedID = source.id
                    onSelect()
                    let polar = MapGeometry.polar(dx: Double(value.location.x - center.x),
                                                  dy: Double(value.location.y - center.y - 10),
                                                  metersPerRadius: metersPerRadius, radiusPixels: Double(radius))
                    model.move(source.id, angle: polar.angle, distance: polar.distance)
                }
        )
        .onTapGesture { model.selectedID = source.id; onSelect() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(source.displayName)
        .accessibilityValue(String(localized: "\(Describe.angle(source.angle)), a \(Describe.meters(source.distance)), volume \(Int(source.volume * 100)) por cento") + (source.muted ? String(localized: ", mudo") : ""))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAdjustableAction { direction in
            model.selectedID = source.id
            model.nudge(source.id, angle: direction == .increment ? 5 : -5)
        }
        .help("\(source.displayName): \(Describe.angle(source.angle)), \(Describe.meters(source.distance))")
    }
}

// MARK: efeito desligado

/// Faixa na base do palco: diz o que está acontecendo e oferece a ação, sem esconder o mapa.
private struct OffState: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        HStack(spacing: Space.l) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Efeito desligado").font(.headline)
                Text("O som do Mac sai normalmente pelo fone.").font(.callout).foregroundStyle(.secondary)
            }
            Spacer(minLength: Space.l)
            if let issue = model.permissionIssue {
                Button("Abrir Ajustes…") { NSWorkspace.shared.open(issue.settingsURL) }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                Button("Tentar de novo") { model.message = nil; model.setEffect(true) }.controlSize(.large)
            } else {
                Button("Ligar efeito espacial") { model.setEffect(true) }
                    .buttonStyle(.borderedProminent).controlSize(.large)
            }
        }
        .padding(Space.l)
        .frame(maxWidth: 560)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.separator))
        .shadow(color: .black.opacity(0.10), radius: 10, y: 3)
    }
}
