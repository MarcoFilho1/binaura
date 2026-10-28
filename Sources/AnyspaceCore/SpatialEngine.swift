import AVFoundation

/// Motor 3D: cada "voz" é um par de pontos no espaço (canal esquerdo e direito de uma fonte estéreo),
/// colocados à esquerda e à direita da direção da fonte, como dois alto-falantes virtuais.
public final class SpatialEngine {
    public typealias Provider = (_ out: UnsafeMutablePointer<Float>, _ count: Int) -> Void

    public let engine = AVAudioEngine()
    public let environment = AVAudioEnvironmentNode()
    private let mono: AVAudioFormat
    private let stereo: AVAudioFormat

    private struct Voice {
        let left: AVAudioSourceNode
        let right: AVAudioSourceNode
        var placement = (angle: Float(0), distance: Float(1), width: Float(30))
    }
    private var voices: [String: Voice] = [:]
    private var algorithm: AVAudio3DMixingRenderingAlgorithm = .HRTFHQ
    private var reverbBlend: Float = 0.2

    public init(sampleRate: Double) {
        mono = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        stereo = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        engine.attach(environment)
        engine.connect(environment, to: engine.mainMixerNode, format: stereo)
        environment.outputType = .headphones
        environment.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        environment.distanceAttenuationParameters.distanceAttenuationModel = .inverse
        environment.distanceAttenuationParameters.referenceDistance = 1
        environment.distanceAttenuationParameters.rolloffFactor = 1
        setReverb(on: false, levelDB: -25)
    }

    private func makeNode(_ provider: @escaping Provider) -> AVAudioSourceNode {
        let node = AVAudioSourceNode(format: mono) { _, _, frameCount, audioBufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            if let data = buffers.first?.mData?.assumingMemoryBound(to: Float.self) {
                provider(data, Int(frameCount))
            }
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: environment, format: mono)
        node.sourceMode = .spatializeIfMono
        node.renderingAlgorithm = algorithm
        node.reverbBlend = reverbBlend
        return node
    }

    public func addVoice(id: String, left: @escaping Provider, right: @escaping Provider) {
        removeVoice(id: id)
        voices[id] = Voice(left: makeNode(left), right: makeNode(right))
        place(id: id, angle: 0, distance: 1, width: 30, volume: 1)
    }

    public func removeVoice(id: String) {
        guard let voice = voices.removeValue(forKey: id) else { return }
        engine.disconnectNodeOutput(voice.left)
        engine.disconnectNodeOutput(voice.right)
        engine.detach(voice.left)
        engine.detach(voice.right)
    }

    public func hasVoice(_ id: String) -> Bool { voices[id] != nil }

    /// `volume` 0...1 (0 = mudo). `width` 0 faz o estéreo colapsar em um único ponto.
    public func place(id: String, angle: Float, distance: Float, width: Float, volume: Float) {
        guard var voice = voices[id] else { return }
        voice.placement = (angle, distance, width)
        voices[id] = voice
        voice.left.position = position(angleDegrees: angle - width, distance: distance)
        voice.right.position = position(angleDegrees: angle + width, distance: distance)
        voice.left.volume = volume
        voice.right.volume = volume
    }

    /// Quanto a cabeça virou, em graus: positivo = virou para a direita.
    /// As fontes ficam paradas no espaço, então ao virar para a direita uma fonte à frente passa para a esquerda.
    public func setHeadYaw(degrees: Float) {
        environment.listenerAngularOrientation = AVAudio3DAngularOrientation(yaw: headYawSign * degrees, pitch: 0, roll: 0)
    }

    /// Sinal que converte "virou para a direita" no `yaw` do AVAudioEnvironmentNode (conferido por anyspace-check).
    let headYawSign: Float = 1

    public static let algorithms: [String: AVAudio3DMixingRenderingAlgorithm] = [
        "HRTFHQ": .HRTFHQ, "HRTF": .HRTF, "sphericalHead": .sphericalHead, "equalPowerPanning": .equalPowerPanning,
    ]

    public func setAlgorithm(_ name: String) {
        algorithm = Self.algorithms[name] ?? .HRTFHQ
        for voice in voices.values {
            voice.left.renderingAlgorithm = algorithm
            voice.right.renderingAlgorithm = algorithm
        }
    }

    public func setReverb(on: Bool, levelDB: Float) {
        environment.reverbParameters.enable = on
        if on {
            environment.reverbParameters.loadFactoryReverbPreset(.smallRoom)
            environment.reverbParameters.level = levelDB
        }
        reverbBlend = on ? 0.2 : 0
        for voice in voices.values {
            voice.left.reverbBlend = reverbBlend
            voice.right.reverbBlend = reverbBlend
        }
    }

    /// Alto-falantes do Mac não têm fones separados por ouvido; o motor usa outro modo de saída para eles.
    public func setOutputKind(speakers: Bool) {
        environment.outputType = speakers ? .builtInSpeakers : .headphones
    }

    public func start() throws { try engine.start() }
    public func stop() { engine.stop() }
}
