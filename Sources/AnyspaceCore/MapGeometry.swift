import Foundation

/// Conversão entre pontos do mapa 2D (você no centro, frente = para cima) e (ângulo, distância).
/// `dx` e `dy` são em pixels a partir do centro, com `dy` positivo para baixo.
public enum MapGeometry {
    public static func polar(dx: Double, dy: Double, metersPerRadius: Double, radiusPixels: Double,
                             minDistance: Double = 0.5) -> (angle: Float, distance: Float) {
        let angle = atan2(dx, -dy) * 180 / .pi
        let meters = min(max(hypot(dx, dy) / radiusPixels * metersPerRadius, minDistance), metersPerRadius)
        return (Float(angle), Float(meters))
    }

    public static func point(angle: Float, distance: Float, metersPerRadius: Double,
                             radiusPixels: Double) -> (dx: Double, dy: Double) {
        let radians = Double(angle) * .pi / 180
        let r = Double(distance) / metersPerRadius * radiusPixels
        return (r * sin(radians), -r * cos(radians))
    }
}
