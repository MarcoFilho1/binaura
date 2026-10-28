import Foundation

public struct SourceSetting: Codable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var angle: Float
    public var distance: Float
    public var volume: Float
    public var muted: Bool

    public init(id: String, name: String, angle: Float = 0, distance: Float = 1, volume: Float = 1, muted: Bool = false) {
        self.id = id; self.name = name; self.angle = angle; self.distance = distance
        self.volume = volume; self.muted = muted
    }
}

/// Tudo o que o usuário configura. Salvo em ~/Library/Application Support/Anyspace/scene.json.
public struct SoundScene: Codable, Equatable {
    public static let restID = "rest"

    public var rest = SourceSetting(id: restID, name: "Resto do sistema")
    public var apps: [SourceSetting] = []
    /// Abertura do estéreo: o canal esquerdo vai a (ângulo − largura) e o direito a (ângulo + largura).
    public var width: Float = 30
    public var reverbOn = true
    public var reverbDB: Float = -25
    public var algorithm = "HRTFHQ"
    public var headTracking = false
    public var cameraName = ""
    public var invertHead = false
    /// Senha dos dispositivos que enviam áudio pela rede (fase 5).
    public var networkPassword = ""

    public init() {}

    public var all: [SourceSetting] { [rest] + apps }

    /// Fontes que chegam pela rede têm id "net:PORTA".
    public static func networkPort(of id: String) -> UInt16? {
        id.hasPrefix("net:") ? UInt16(id.dropFirst(4)) : nil
    }

    public mutating func update(_ s: SourceSetting) {
        if s.id == Self.restID { rest = s } else if let i = apps.firstIndex(where: { $0.id == s.id }) { apps[i] = s }
    }
}

public enum SceneStore {
    public static var url: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Anyspace/scene.json")
    }

    public static func load(from url: URL = url) -> SoundScene {
        guard let data = try? Data(contentsOf: url), let scene = try? JSONDecoder().decode(SoundScene.self, from: data) else {
            return SoundScene()
        }
        return scene
    }

    public static func save(_ scene: SoundScene, to url: URL = url) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(scene) { try? data.write(to: url, options: .atomic) }
    }
}
