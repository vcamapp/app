import Foundation
import VCamEntity
import VCamLocalization
import VCamBridge

public struct VCamSceneDataStore {
    public init(sceneId: Int32) {
        self.sceneId = sceneId
    }

    public let sceneId: Int32

    private var sceneRootURL: URL {
        .sceneRoot(sceneId: sceneId)
    }

    private var sceneURL: URL {
        .scene(sceneId: sceneId)
    }

    public func load() throws -> VCamScene {
        let data = try Data(contentsOf: sceneURL)
        let decoder = JSONDecoder()
        return try decoder.decode(VCamScene.self, from: data)
    }

    public func save(_ scene: VCamScene) throws {
        try? FileManager.default.createDirectoryIfNeeded(at: sceneRootURL)

        let url = sceneURL
        let encoder = JSONEncoder()
        let data = try encoder.encode(scene)
        try data.write(to: url)
        uniDebugLog("scene saved: " + url.path)
    }

    public func copyData(fromURL url: URL, newUUID: String = UUID().uuidString) -> URL {
        let destination: URL
        if url.path.hasPrefix(sceneRootURL.path) {
            uniDebugLog("copyData: \(url.lastPathComponent)")
            destination = url
        } else {
            destination = dataURL(id: newUUID)
            uniDebugLog(destination.path)

            try? FileManager.default.createDirectoryIfNeeded(at: sceneRootURL)
            do {
                try FileManager.default.copyItem(at: url, to: destination)
            } catch {
                uniDebugLog(error.localizedDescription)
            }
        }
        uniDebugLog("from: \(url.path), dest: \(destination.path)")
        return destination
    }

    static func dataId(fromURL url: URL) throws -> UUID {
        try UUID(uuidString: url.lastPathComponent).orThrow(NSError.vcam(message: "dataId:failed to generate UUID"))
    }

    public func dataURL(id: String) -> URL {
        sceneRootURL.appending(path: id)
    }

    public func delete() throws {
        try FileManager.default.removeItem(at: sceneRootURL)
    }
}

extension VCamSceneDataStore {
    public static let defaultObjects: [SceneObject] = [
        .init(id: SceneObject.avatarID, type: .avatar(.init()), isHidden: false, isLocked: false)
    ]

    public func makeNewScene() -> VCamScene {
        try? addSceneIdIfNeeded()
        return .init(id: sceneId, name: L10n.scene.text, objects: [
            .init(id: SceneObject.avatarID, name: L10n.avatar.text, type: .avatar(state: .zero), isHidden: false, isLocked: false)
        ], aspectRatio: MainTexture.shared.aspectRatio)
    }

    public func makeScene(name: String, objects: [SceneObject]) throws -> VCamScene {
        try addSceneIdIfNeeded()
        uniDebugLog("makeScene: \(objects.count)")

        var results: [VCamScene.Object] = []
        for object in objects {
            do {
                uniDebugLog("makeScene: \(object)")
                results.append(try object.encodeScene())
            } catch {
                uniDebugLog(error.localizedDescription)
            }
        }

        return .init(id: sceneId, name: name, objects: results, aspectRatio: MainTexture.shared.aspectRatio)
    }

    private func addSceneIdIfNeeded() throws {
        var metadata = VCamSceneMetadata.loadOrCreate()
        if !metadata.sceneIds.contains(sceneId) {
            metadata.sceneIds.append(sceneId)
            try metadata.save()
        }
    }
}

extension VCamSceneDataStore { // TODO: Refactor
    public static func clean(metadata: VCamSceneMetadata) throws -> VCamSceneMetadata {
        // Remove the scenes if there're data inconsistency

        let dataIds = (try FileManager.default.contentsOfDirectory(atPath: URL.scenesDirectory.path)
            .compactMap { $0.components(separatedBy: "/").last })
            .compactMap(Int32.init)
            .filter { FileManager.default.fileExists(atPath: URL.scene(sceneId: $0).path) }

        // Exclude scenes where the data file is missing
        var existingIds = dataIds.filter { metadata.sceneIds.contains($0) }
        existingIds = existingIds.filter { id in
            // Remove objects that cannot be loaded
            do {
                let dataStore = Self.init(sceneId: id)
                var scene = try dataStore.load()
                scene.objects = scene.objects.compactMap {
                    switch $0.type {
                    case .avatar, .screen, .captureDevice, .web, .wind: ()
                    case let .image(id, _):
                        if !FileManager.default.fileExists(atPath: dataStore.dataURL(id: id).path) {
                            return nil
                        }
                    }
                    return $0
                }
                try dataStore.save(scene)
                return true
            } catch {
                try? FileManager.default.removeItem(at: .sceneRoot(sceneId: id))
                return false
            }
        }

        if Set(metadata.sceneIds) != Set(existingIds) {
            var metadata = metadata
            metadata.sceneIds = metadata.sceneIds.filter { existingIds.contains($0) }
            try metadata.save()
            return metadata
        }

        return metadata
    }
}
