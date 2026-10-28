import Foundation

/// Transforma as medições brutas e ruidosas do ângulo da cabeça (graus, + = virou para a direita)
/// em um ângulo suave para o ouvinte 3D.
///  - suavização exponencial (tau pequeno = acompanha rápido, tau grande = menos tremor)
///  - zona morta: mudanças menores que `deadZone` graus são ignoradas
///  - rosto perdido: mantém o último ângulo por `holdSeconds` e volta devagar ao centro
///  - `calibrate()` define o centro como a última medição
public struct HeadFilter {
    public var tau: Float = 0.08
    public var deadZone: Float = 1.0
    public var holdSeconds: Float = 1.5
    public var returnTau: Float = 1.5
    public var maxAngle: Float = 90

    public private(set) var output: Float = 0
    private var center: Float = 0
    private var lastRaw: Float = 0
    private var sinceSeen: Float = 0

    public init() {}

    public mutating func calibrate() { center = lastRaw }

    @discardableResult
    public mutating func update(raw: Float?, dt: Float) -> Float {
        if let raw {
            lastRaw = raw
            sinceSeen = 0
            let target = max(-maxAngle, min(maxAngle, raw - center))
            if abs(target - output) > deadZone {
                output += (1 - exp(-dt / tau)) * (target - output)
            }
        } else {
            sinceSeen += dt
            if sinceSeen > holdSeconds {
                output += (1 - exp(-dt / returnTau)) * (0 - output)
            }
        }
        return output
    }
}
