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

/// Um conjunto salvo de posições e ajustes de som (ex.: "Trabalho", "Filme").
/// Não guarda câmera nem senha da rede, que são da máquina e não do ambiente.
public struct SoundProfile: Codable, Equatable, Identifiable {
    public var name: String
    public var rest: SourceSetting
    public var apps: [SourceSetting]
    public var width: Float
    public var reverbOn: Bool
    public var reverbDB: Float
    public var algorithm: String

    public var id: String { name }
}

/// Tudo o que o usuário configura. Salvo em ~/Library/Application Support/Binaura/scene.json.
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
    public var invertHead = true
    /// Senha dos dispositivos que enviam áudio pela rede (fase 5).
    public var networkPassword = ""
    public var profiles: [SoundProfile] = []

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case rest, apps, width, reverbOn, reverbDB, algorithm, headTracking, cameraName, invertHead, networkPassword, profiles
    }

    /// Campos ausentes (arquivos de versões antigas) ficam com o valor padrão em vez de perder a cena inteira.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = SoundScene()
        rest = try c.decodeIfPresent(SourceSetting.self, forKey: .rest) ?? d.rest
        apps = try c.decodeIfPresent([SourceSetting].self, forKey: .apps) ?? d.apps
        width = try c.decodeIfPresent(Float.self, forKey: .width) ?? d.width
        reverbOn = try c.decodeIfPresent(Bool.self, forKey: .reverbOn) ?? d.reverbOn
        reverbDB = try c.decodeIfPresent(Float.self, forKey: .reverbDB) ?? d.reverbDB
        algorithm = try c.decodeIfPresent(String.self, forKey: .algorithm) ?? d.algorithm
        headTracking = try c.decodeIfPresent(Bool.self, forKey: .headTracking) ?? d.headTracking
        cameraName = try c.decodeIfPresent(String.self, forKey: .cameraName) ?? d.cameraName
        invertHead = try c.decodeIfPresent(Bool.self, forKey: .invertHead) ?? d.invertHead
        networkPassword = try c.decodeIfPresent(String.self, forKey: .networkPassword) ?? d.networkPassword
        profiles = try c.decodeIfPresent([SoundProfile].self, forKey: .profiles) ?? d.profiles
    }

    // MARK: perfis

    /// Salva o estado atual com esse nome (substitui um perfil de mesmo nome).
    public mutating func saveProfile(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let profile = SoundProfile(name: trimmed, rest: rest, apps: apps, width: width,
                                   reverbOn: reverbOn, reverbDB: reverbDB, algorithm: algorithm)
        if let i = profiles.firstIndex(where: { $0.name == trimmed }) { profiles[i] = profile } else { profiles.append(profile) }
    }

    @discardableResult
    public mutating func applyProfile(named name: String) -> Bool {
        guard let p = profiles.first(where: { $0.name == name }) else { return false }
        rest = p.rest; apps = p.apps; width = p.width
        reverbOn = p.reverbOn; reverbDB = p.reverbDB; algorithm = p.algorithm
        return true
    }

    public mutating func deleteProfile(named name: String) { profiles.removeAll { $0.name == name } }

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
        return base.appendingPathComponent("Binaura/scene.json")
    }

    /// Pasta antiga, do tempo em que o projeto se chamava Anyspace.
    private static var legacyURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Anyspace/scene.json")
    }

    /// Na primeira abertura depois da troca de nome, copia a cena antiga (perfis e posições) para a pasta nova.
    public static func migrateLegacyScene() {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: url.path), fm.fileExists(atPath: legacyURL.path) else { return }
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? fm.copyItem(at: legacyURL, to: url)
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
