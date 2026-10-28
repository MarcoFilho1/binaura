import AVFoundation

/// Convenção do Anyspace: ângulo 0° = à frente, +90° = à direita, -90° = à esquerda, 180° = atrás.
/// O ouvinte olha para -z e a direita dele é +x (convenção do AVAudioEnvironmentNode).
public func position(angleDegrees: Float, distance: Float) -> AVAudio3DPoint {
    let radians = angleDegrees * .pi / 180
    return AVAudio3DPoint(x: distance * sin(radians), y: 0, z: -distance * cos(radians))
}
