import AppKit
import CoreAudio
import Foundation

/// Um aplicativo que usa áudio. Navegadores e outros apps tocam por vários processos auxiliares,
/// que aqui são agrupados no app principal.
public struct AudioApp: Identifiable, Hashable {
    public let id: String          // bundle id do app principal
    public let name: String
    public var processes: [AudioObjectID]
    public var isPlaying: Bool
}

/// "com.google.Chrome.helper.Renderer" → "com.google.Chrome"; processos do WebKit → Safari.
public func rootBundleID(_ bundleID: String) -> String {
    if bundleID.hasPrefix("com.apple.WebKit.") { return "com.apple.Safari" }
    let lower = bundleID.lowercased()
    if let range = lower.range(of: ".helper") {
        let end = bundleID.index(bundleID.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: range.lowerBound))
        return String(bundleID[bundleID.startIndex..<end])
    }
    return bundleID
}

public func listAudioApps(excludingPID excluded: pid_t = getpid()) -> [AudioApp] {
    var addr = address(kAudioHardwarePropertyProcessObjectList)
    var size: UInt32 = 0
    let system = AudioObjectID(kAudioObjectSystemObject)
    guard AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
    var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
    guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &ids) == noErr else { return [] }

    var groups: [String: AudioApp] = [:]
    for id in ids {
        let bundle = stringProperty(id, kAudioProcessPropertyBundleID)
        let pid = pid_t(uint32Property(id, kAudioProcessPropertyPID))
        guard !bundle.isEmpty, pid != excluded else { continue }
        let root = rootBundleID(bundle)
        let playing = uint32Property(id, kAudioProcessPropertyIsRunningOutput) != 0
        if var app = groups[root] {
            app.processes.append(id)
            app.isPlaying = app.isPlaying || playing
            groups[root] = app
        } else {
            let name = NSRunningApplication.runningApplications(withBundleIdentifier: root).first?.localizedName
                ?? root.split(separator: ".").last.map(String.init) ?? root
            groups[root] = AudioApp(id: root, name: name, processes: [id], isPlaying: playing)
        }
    }
    return groups.values.sorted { ($0.isPlaying ? 0 : 1, $0.name) < ($1.isPlaying ? 0 : 1, $1.name) }
}
