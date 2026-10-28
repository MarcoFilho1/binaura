import Foundation

/// Yaw contínuo a partir da geometria do rosto.
///
/// O `yaw` do Vision é um classificador de três posições (0°, ±45°, ±90°): quase nunca passa de um degrau
/// para o outro de forma gradual, e isso aparece como "pulos" de 45° no som. Aqui usamos duas razões que
/// variam de forma contínua com a rotação da cabeça:
///  - `fMedian`: deslocamento da linha central do rosto em relação ao meio do contorno, dividido pela largura.
///    Chega a ±0,5 quando o rosto está de perfil (a linha central encosta na borda).
///  - `fEyes`: o mesmo para o ponto médio dos olhos; chega a cerca de ±0,34 de perfil.
/// O ângulo é `asin(f / fmax)`. Os valores de `fmax` vêm de uma gravação real (Mac, ~35 s): na faixa em que o Vision
/// dizia -45° a média estimada deu -43°. A mistura pesa mais os olhos, que têm menos ruído.
public func estimateYaw(fMedian: Float?, fEyes: Float?, fallbackDegrees: Float) -> Float {
    func angle(_ f: Float, _ maxValue: Float) -> Float {
        asin(max(-0.95, min(0.95, f / maxValue))) * 180 / .pi
    }
    var parts: [(Float, Float)] = []
    if let fMedian { parts.append((angle(fMedian, 0.5), 1.0)) }
    if let fEyes { parts.append((angle(fEyes, 0.34), 1.8)) }
    guard !parts.isEmpty else { return fallbackDegrees }
    return parts.reduce(0) { $0 + $1.0 * $1.1 } / parts.reduce(0) { $0 + $1.1 }
}
