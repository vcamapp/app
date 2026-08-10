import Foundation
import VCamEntity

public extension VCamSceneMetadata {
    static func loadOrCreate(from url: URL = .sceneMetadata) throws -> VCamSceneMetadata {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .init()
        }
        return try load(from: url)
    }

    static func load(from url: URL = .sceneMetadata) throws -> VCamSceneMetadata {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(VCamSceneMetadata.self, from: data)
    }

    func save(to url: URL = .sceneMetadata) throws {
        let data = try JSONEncoder().encode(self)
        try FileManager.default.createDirectoryIfNeeded(at: url.deletingLastPathComponent())
        try data.write(to: url, options: .atomic)
    }
}
