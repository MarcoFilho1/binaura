import AVFoundation

/// Pega um fluxo mono e o coloca em um ponto do espaço 3D (HRTF para fones).
/// `provider` é chamado na thread de áudio: deve preencher `count` amostras mono.
public final class SpatialEngine {
    public typealias Provider = (_ out: UnsafeMutablePointer<Float>, _ count: Int) -> Void

    public let engine = AVAudioEngine()
    public let environment = AVAudioEnvironmentNode()
    private var source: AVAudioSourceNode!

    public init(sampleRate: Double, provider: @escaping Provider) {
        let mono = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let stereo = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

        source = AVAudioSourceNode(format: mono) { _, _, frameCount, audioBufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            if let data = buffers.first?.mData?.assumingMemoryBound(to: Float.self) {
                provider(data, Int(frameCount))
            }
            return noErr
        }

        engine.attach(source)
        engine.attach(environment)
        engine.connect(source, to: environment, format: mono)
        engine.connect(environment, to: engine.mainMixerNode, format: stereo)

        source.sourceMode = .spatializeIfMono
        source.renderingAlgorithm = .HRTFHQ
        environment.outputType = .headphones
        environment.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        environment.distanceAttenuationParameters.distanceAttenuationModel = .inverse
        environment.distanceAttenuationParameters.referenceDistance = 1
        environment.distanceAttenuationParameters.rolloffFactor = 1
        setSource(angleDegrees: 0, distance: 1)
    }

    public func setSource(angleDegrees: Float, distance: Float) {
        source.position = position(angleDegrees: angleDegrees, distance: distance)
    }

    /// Rotação da cabeça do ouvinte, em graus (usada na fase 2).
    public func setListenerYaw(degrees: Float) {
        environment.listenerAngularOrientation = AVAudio3DAngularOrientation(yaw: degrees, pitch: 0, roll: 0)
    }

    public func start() throws { try engine.start() }
    public func stop() { engine.stop() }
}
