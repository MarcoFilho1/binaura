import CoreAudio
import Foundation
import CoreAudio

public func check(_ status: OSStatus, _ what: String) {
    guard status == noErr else {
        fputs("erro: \(what) (OSStatus \(status))\n", stderr)
        exit(1)
    }
}

public func address(
    _ selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
}

public func uint32Property(
    _ object: AudioObjectID,
    _ selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
) -> UInt32 {
    var addr = address(selector, scope: scope)
    var value: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    AudioObjectGetPropertyData(object, &addr, 0, nil, &size, &value)
    return value
}

public func float64Property(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> Float64 {
    var addr = address(selector)
    var value: Float64 = 0
    var size = UInt32(MemoryLayout<Float64>.size)
    AudioObjectGetPropertyData(object, &addr, 0, nil, &size, &value)
    return value
}

public func stringProperty(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String {
    var addr = address(selector)
    var value: CFString? = nil
    var size = UInt32(MemoryLayout<CFString?>.size)
    AudioObjectGetPropertyData(object, &addr, 0, nil, &size, &value)
    return (value as String?) ?? ""
}

public func defaultOutputDevice() -> AudioObjectID {
    var addr = address(kAudioHardwarePropertyDefaultOutputDevice)
    var device = AudioObjectID(kAudioObjectUnknown)
    var size = UInt32(MemoryLayout<AudioObjectID>.size)
    check(
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &device),
        "ler dispositivo de saída padrão"
    )
    return device
}

/// Descreve os buffers de entrada ou saída de um dispositivo (para depuração).
public func streamLayout(_ device: AudioObjectID, scope: AudioObjectPropertyScope) -> [UInt32] {
    var addr = address(kAudioDevicePropertyStreamConfiguration, scope: scope)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(device, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
    let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
    defer { raw.deallocate() }
    guard AudioObjectGetPropertyData(device, &addr, 0, nil, &size, raw) == noErr else { return [] }
    let list = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
    return list.map { $0.mNumberChannels }
}

/// Atraso total (em ms) que o dispositivo declara para um dos lados.
public func latencyMs(_ device: AudioObjectID, scope: AudioObjectPropertyScope) -> Double {
    let rate = float64Property(device, kAudioDevicePropertyNominalSampleRate)
    guard rate > 0 else { return 0 }
    let frames = uint32Property(device, kAudioDevicePropertyLatency, scope: scope)
        + uint32Property(device, kAudioDevicePropertySafetyOffset, scope: scope)
        + uint32Property(device, kAudioDevicePropertyBufferFrameSize, scope: scope)
    return Double(frames) / rate * 1000
}

/// Objeto de áudio deste processo. Só existe depois que o processo usa áudio,
/// então abrimos a saída por um instante, em silêncio, para registrá-lo.
public func ownProcessObject(registeringOn output: AudioObjectID) -> AudioObjectID {
    func lookup() -> AudioObjectID {
        var addr = address(kAudioHardwarePropertyTranslatePIDToProcessObject)
        var pid = getpid()
        var object = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr,
            UInt32(MemoryLayout<pid_t>.size), &pid, &size, &object
        )
        return object
    }

    let found = lookup()
    if found != kAudioObjectUnknown { return found }

    var proc: AudioDeviceIOProcID?
    check(AudioDeviceCreateIOProcIDWithBlock(&proc, output, nil) { _, _, _, _, _ in }, "criar IOProc de registro")
    check(AudioDeviceStart(output, proc), "iniciar IOProc de registro")
    Thread.sleep(forTimeInterval: 0.3)
    let object = lookup()
    AudioDeviceStop(output, proc)
    AudioDeviceDestroyIOProcID(output, proc!)
    return object
}

/// Verdadeiro para os alto-falantes embutidos do Mac (qualquer outra saída é tratada como fone).
public func isBuiltInSpeaker(_ device: AudioObjectID) -> Bool {
    uint32Property(device, kAudioDevicePropertyTransportType) == kAudioDeviceTransportTypeBuiltIn
        && stringProperty(device, kAudioObjectPropertyName).localizedCaseInsensitiveContains("speaker")
}
