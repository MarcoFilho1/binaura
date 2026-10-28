import CoreAudio
import Foundation

// Fase 0: captura todo o som do sistema (menos o do próprio Anyspace),
// silencia a saída original e toca o mesmo som no dispositivo de saída padrão.

setvbuf(stdout, nil, _IOLBF, 0)

let outputDevice = defaultOutputDevice()
let outputUID = stringProperty(outputDevice, kAudioDevicePropertyDeviceUID)
let outputName = stringProperty(outputDevice, kAudioObjectPropertyName)
print("Saída: \(outputName)")

let selfProcess = ownProcessObject(registeringOn: outputDevice)
if selfProcess == kAudioObjectUnknown {
    fputs("aviso: não achei o processo do Anyspace; o som pode realimentar\n", stderr)
}

let tapDescription = CATapDescription(
    stereoGlobalTapButExcludeProcesses: selfProcess == kAudioObjectUnknown ? [] : [selfProcess]
)
tapDescription.name = "Anyspace"
tapDescription.isPrivate = true
tapDescription.muteBehavior = .muted

var tapID = AudioObjectID(kAudioObjectUnknown)
check(AudioHardwareCreateProcessTap(tapDescription, &tapID), "criar tap (permissão de áudio concedida?)")

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
        kAudioSubTapUIDKey: tapDescription.uuid.uuidString,
    ]],
]
var aggregateID = AudioObjectID(kAudioObjectUnknown)
check(AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID), "criar dispositivo agregado")

print("Entradas do agregado (canais por buffer): \(streamLayout(aggregateID, scope: kAudioObjectPropertyScopeInput))")
print("Saídas do agregado (canais por buffer): \(streamLayout(aggregateID, scope: kAudioObjectPropertyScopeOutput))")
print(String(format: "Atraso declarado: entrada %.1f ms + saída %.1f ms (o Bluetooth real é maior e não aparece aqui)",
             latencyMs(aggregateID, scope: kAudioObjectPropertyScopeInput),
             latencyMs(aggregateID, scope: kAudioObjectPropertyScopeOutput)))

// --teste: só o ouvido esquerdo recebe som, para você notar se o Anyspace está mesmo no caminho.
let leftOnlyTest = CommandLine.arguments.contains("--teste")

// Pico do último bloco, só para mostrar que o som está passando.
let peak = UnsafeMutablePointer<Float>.allocate(capacity: 1)
peak.pointee = 0

var procID: AudioDeviceIOProcID?
check(AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, nil) { _, inData, _, outData, _ in
    let inputs = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inData))
    let outputs = UnsafeMutableAudioBufferListPointer(outData)
    guard let source = inputs.last, let sourceData = source.mData,
          let first = outputs.first, let destData = first.mData else { return }

    let bytes = Int(min(source.mDataByteSize, first.mDataByteSize))
    memcpy(destData, sourceData, bytes)
    if bytes < Int(first.mDataByteSize) {
        memset(destData + bytes, 0, Int(first.mDataByteSize) - bytes)
    }

    if leftOnlyTest {
        let out = destData.assumingMemoryBound(to: Float.self)
        for i in stride(from: 1, to: bytes / MemoryLayout<Float>.size, by: 2) { out[i] = 0 }
    }

    let samples = sourceData.assumingMemoryBound(to: Float.self)
    var maxValue: Float = 0
    for i in 0..<(bytes / MemoryLayout<Float>.size) { maxValue = max(maxValue, abs(samples[i])) }
    peak.pointee = max(peak.pointee, maxValue)
}, "criar IOProc")
check(AudioDeviceStart(aggregateID, procID), "iniciar áudio")
print("Rodando. Toque algo no Mac e ouça no fone. Ctrl+C para sair.")

func shutdown() {
    AudioDeviceStop(aggregateID, procID)
    AudioDeviceDestroyIOProcID(aggregateID, procID!)
    AudioHardwareDestroyAggregateDevice(aggregateID)
    AudioHardwareDestroyProcessTap(tapID)
    print("\nEncerrado; o som volta ao normal.")
    exit(0)
}

// --seconds N: encerra sozinho e devolve o som ao normal (rede de segurança para testes).
if let flag = CommandLine.arguments.firstIndex(of: "--seconds"),
   CommandLine.arguments.count > flag + 1, let seconds = Double(CommandLine.arguments[flag + 1]) {
    print("Encerra sozinho em \(Int(seconds)) s.")
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { shutdown() }
}

signal(SIGINT, SIG_IGN)
signal(SIGTERM, SIG_IGN)
let signals = [SIGINT, SIGTERM].map { sig -> DispatchSourceSignal in
    let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
    source.setEventHandler { shutdown() }
    source.resume()
    return source
}

let meter = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
    let level = peak.pointee
    peak.pointee = 0
    let bars = String(repeating: "█", count: min(30, Int(level * 30)))
    print(String(format: "nível %.3f ", level) + bars)
}
_ = meter
RunLoop.main.run()
