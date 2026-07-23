import Foundation
import VCamEntity
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
        try data.write(to: url, options: .atomic)
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
    public static var defaultObjects: [SceneObject] {
        [
            .init(id: SceneObject.avatarID, type: .avatar(.init()), isHidden: false, isLocked: false)
        ]
    }

    public func makeNewScene() -> VCamScene {
        try? addSceneIdIfNeeded()
        return .init(id: sceneId, name: "", objects: [
            .init(id: SceneObject.avatarID, name: "", type: .avatar(state: .zero), isHidden: false, isLocked: false)
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

extension VCamSceneDataStore {
    /// Loads every scene while repairing data inconsistencies in a single pass:
    /// drops scenes that can't be loaded, removes image objects whose files are missing,
    /// rebuilds the metadata from the surviving (deduplicated) IDs, and persists only what changed.
    public static func loadAndRepair(metadata: VCamSceneMetadata) throws -> (scenes: [VCamScene], metadata: VCamSceneMetadata) {
        var scenes: [VCamScene] = []
        var validIds: [Int32] = []

        for id in metadata.sceneIds where !validIds.contains(id) {
            let dataStore = Self.init(sceneId: id)
            do {
                var scene = try dataStore.load()
                // Remove image objects whose data files are missing
                let originalCount = scene.objects.count
                scene.objects = scene.objects.compactMap {
                    switch $0.type {
                    case .avatar, .screen, .captureDevice, .web, .wind: ()
                    case let .image(imageId, _):
                        if !FileManager.default.fileExists(atPath: dataStore.dataURL(id: imageId).path) {
                            return nil
                        }
                    }
                    return $0
                }
                // Only rewrite the scene when an invalid object was actually removed
                if scene.objects.count != originalCount {
                    try dataStore.save(scene)
                }
                scenes.append(scene)
                validIds.append(id)
            } catch {
                // Scenes that couldn't be loaded are deleted
                try? dataStore.delete()
            }
        }

        var metadata = metadata
        // Compare as ordered arrays so duplicate IDs (e.g. [1, 1]) are also repaired
        if validIds != metadata.sceneIds {
            metadata.sceneIds = validIds
            try metadata.save()
        }
        return (scenes, metadata)
    }
}
