import AnyspaceCore
import CoreAudio
import Foundation

/// Captura o som de todo o sistema (menos o do próprio Anyspace), silencia a saída original
/// e entrega o áudio misturado em mono para o motor 3D.
final class TapCapture {
    let outputDevice = defaultOutputDevice()
    private(set) var sampleRate: Double = 48000
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private let scratch = UnsafeMutablePointer<Float>.allocate(capacity: 16384)

    /// Maior valor absoluto recente, só para o medidor.
    let peak = UnsafeMutablePointer<Float>.allocate(capacity: 1)

    init() { peak.pointee = 0 }

    func start(into ring: MonoRingBuffer) {
        let outputUID = stringProperty(outputDevice, kAudioDevicePropertyDeviceUID)
        sampleRate = float64Property(outputDevice, kAudioDevicePropertyNominalSampleRate)

        let selfProcess = ownProcessObject(registeringOn: outputDevice)
        if selfProcess == kAudioObjectUnknown {
            fputs("aviso: não achei o processo do Anyspace; o som pode realimentar\n", stderr)
        }
        let description = CATapDescription(
            stereoGlobalTapButExcludeProcesses: selfProcess == kAudioObjectUnknown ? [] : [selfProcess]
        )
        description.name = "Anyspace"
        description.isPrivate = true
        description.muteBehavior = .muted
        check(AudioHardwareCreateProcessTap(description, &tapID), "criar tap (permissão de áudio concedida?)")

        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Anyspace",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapDriftCompensationKey: true,
                kAudioSubTapUIDKey: description.uuid.uuidString,
            ]],
        ]
        check(AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID), "criar dispositivo agregado")

        let scratch = scratch, peak = peak
        check(AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, nil) { _, inData, _, outData, _ in
            // O agregado também tem uma saída; ela fica muda (quem toca é o motor 3D).
            for buffer in UnsafeMutableAudioBufferListPointer(outData) {
                if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) }
            }
            let inputs = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inData))
            guard let source = inputs.last, let data = source.mData, source.mNumberChannels == 2 else { return }

            let frames = min(Int(source.mDataByteSize) / (2 * MemoryLayout<Float>.size), 16384)
            let samples = data.assumingMemoryBound(to: Float.self)
            var maxValue: Float = 0
            for i in 0..<frames {
                scratch[i] = (samples[2 * i] + samples[2 * i + 1]) * 0.5
                maxValue = max(maxValue, abs(scratch[i]))
            }
            peak.pointee = max(peak.pointee, maxValue)
            ring.write(scratch, count: frames)
        }, "criar IOProc")
        check(AudioDeviceStart(aggregateID, procID), "iniciar captura")
    }

    func stop() {
        AudioDeviceStop(aggregateID, procID)
        if let procID { AudioDeviceDestroyIOProcID(aggregateID, procID) }
        AudioHardwareDestroyAggregateDevice(aggregateID)
        AudioHardwareDestroyProcessTap(tapID)
    }
}
