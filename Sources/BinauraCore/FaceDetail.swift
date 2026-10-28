import CoreGraphics
import Foundation

/// Rosto medido em um quadro da câmera, para a janela de depuração.
/// Todos os pontos estão em 0...1 na imagem, com origem embaixo à esquerda e sem espelhar.
public struct FaceDetail: Equatable {
    public var box: CGRect
    /// Graus; positivo = a cabeça virou para a direita da pessoa (já com o sinal de "Inverter" aplicado).
    public var yaw: Float
    /// Graus; positivo = para cima. A convenção do Vision ainda precisa ser confirmada na prática.
    public var pitch: Float?
    public var roll: Float?
    /// Pontos-chave do rosto (~37), em ordem fixa, e os triângulos que os ligam (índices de `mesh`).
    public var mesh: [CGPoint]
    public var meshTriangles: [[Int]]
    public var pupils: [CGPoint]
    /// Estimativa do olhar (cabeça + posição da pupila no olho). Não é calibrada: serve para comparar, não para medir.
    public var gazeYaw: Float?
    public var gazePitch: Float?
    /// Yaw do Vision em graus, sem o sinal de "Inverter" e sem nenhum filtro (para diagnóstico).
    public var rawYawDeg: Float = 0
    /// Razões geométricas do rosto (posição do nariz entre os contornos etc.), para estimar um yaw contínuo.
    public var features: [String: Float] = [:]

    public init(box: CGRect, yaw: Float, pitch: Float? = nil, roll: Float? = nil, mesh: [CGPoint] = [], meshTriangles: [[Int]] = [],
                pupils: [CGPoint] = [], gazeYaw: Float? = nil, gazePitch: Float? = nil) {
        self.box = box; self.yaw = yaw; self.pitch = pitch; self.roll = roll
        self.mesh = mesh; self.meshTriangles = meshTriangles; self.pupils = pupils; self.gazeYaw = gazeYaw; self.gazePitch = gazePitch
    }
}

/// Onde a pessoa parece olhar dentro da tela, de -1 a 1 em cada eixo (0,0 = centro), a partir do olhar estimado.
/// Cerca de ±30° na horizontal e ±20° na vertical cobrem a tela; fora disso o ponto encosta na borda.
public func screenPoint(gazeYaw: Float, gazePitch: Float) -> (x: Float, y: Float) {
    (max(-1, min(1, gazeYaw / 30)), max(-1, min(1, gazePitch / 20)))
}
