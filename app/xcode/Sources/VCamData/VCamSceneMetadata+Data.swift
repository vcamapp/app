import Foundation
import VCamEntity

public extension VCamSceneMetadata {
    static func loadOrCreate() -> VCamSceneMetadata {
        (try? load()) ?? .init()
    }

    static func load() throws -> VCamSceneMetadata {
        let data = try Data(contentsOf: .sceneMetadata)
        return try JSONDecoder().decode(VCamSceneMetadata.self, from: data)
    }

    func save() throws {
        let data = try JSONEncoder().encode(self)
        try data.write(to: .sceneMetadata, options: .atomic)
    }
}
