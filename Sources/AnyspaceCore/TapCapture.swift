import CoreAudio
import Foundation

/// Captura o som de um grupo de processos (ou do resto do sistema), silencia a saída original
/// e escreve o estéreo em dois buffers circulares (esquerdo e direito).
public final class TapCapture {
    public enum Target: Equatable {
        case processes([AudioObjectID])
        case restOfSystem(excluding: [AudioObjectID])
    }

    public let target: Target
    private let muteOriginal: Bool
    public let left: MonoRingBuffer
    public let right: MonoRingBuffer
    private let outputDevice: AudioObjectID
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private var scratchL = UnsafeMutablePointer<Float>.allocate(capacity: 16384)
    private var scratchR = UnsafeMutablePointer<Float>.allocate(capacity: 16384)

    /// Maior valor absoluto recente, para medidores e para saber se há som tocando.
    public let peak = UnsafeMutablePointer<Float>.allocate(capacity: 1)

    public init(target: Target, outputDevice: AudioObjectID, left: MonoRingBuffer, right: MonoRingBuffer, muteOriginal: Bool = true) {
        self.target = target
        self.muteOriginal = muteOriginal
        self.outputDevice = outputDevice
        self.left = left
        self.right = right
        peak.pointee = 0
    }

    deinit {
        scratchL.deallocate(); scratchR.deallocate(); peak.deallocate()
    }

    /// Devolve uma mensagem de erro, ou nil se deu certo.
    public func start() -> String? {
        let outputUID = stringProperty(outputDevice, kAudioDevicePropertyDeviceUID)
        let selfProcess = ownProcessObject(registeringOn: outputDevice)

        let description: CATapDescription
        switch target {
        case .processes(let ids):
            description = CATapDescription(stereoMixdownOfProcesses: ids)
        case .restOfSystem(let excluded):
            var all = excluded
            if selfProcess != kAudioObjectUnknown { all.append(selfProcess) }
            description = CATapDescription(stereoGlobalTapButExcludeProcesses: all)
        }
        description.name = "Anyspace"
        description.isPrivate = true
        description.muteBehavior = muteOriginal ? .muted : .unmuted
        var status = AudioHardwareCreateProcessTap(description, &tapID)
        guard status == noErr else { return "criar tap (OSStatus \(status)); permissão de áudio concedida?" }

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
        status = AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID)
        guard status == noErr else { stop(); return "criar dispositivo agregado (OSStatus \(status))" }

        let (scratchL, scratchR, peak, left, right) = (self.scratchL, self.scratchR, self.peak, self.left, self.right)
        status = AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, nil) { _, inData, _, outData, _ in
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
                scratchL[i] = samples[2 * i]
                scratchR[i] = samples[2 * i + 1]
                maxValue = max(maxValue, abs(scratchL[i]), abs(scratchR[i]))
            }
            peak.pointee = max(peak.pointee, maxValue)
            left.write(scratchL, count: frames)
            right.write(scratchR, count: frames)
        }
        guard status == noErr else { stop(); return "criar IOProc (OSStatus \(status))" }
        status = AudioDeviceStart(aggregateID, procID)
        guard status == noErr else { stop(); return "iniciar captura (OSStatus \(status))" }
        return nil
    }

    public func stop() {
        if aggregateID != kAudioObjectUnknown {
            AudioDeviceStop(aggregateID, procID)
            if let procID { AudioDeviceDestroyIOProcID(aggregateID, procID) }
            procID = nil
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = AudioObjectID(kAudioObjectUnknown)
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
    }
}
