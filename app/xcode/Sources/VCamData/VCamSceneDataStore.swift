import Foundation
import VCamEntity
import VCamBridge
import VCamLogger

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
        var scene = try decoder.decode(VCamScene.self, from: data)
        scene.migrateToCurrentVersion()
        return scene
    }

    public func save(_ scene: VCamScene) throws {
        try save(scene, registeringSceneID: false)
    }

    public func saveNew(_ scene: VCamScene) throws {
        try save(scene, registeringSceneID: true)
    }

    private func save(_ scene: VCamScene, registeringSceneID: Bool) throws {
        try FileManager.default.createDirectoryIfNeeded(at: sceneRootURL)

        let url = sceneURL
        let encoder = JSONEncoder()
        let data = try encoder.encode(scene)
        if registeringSceneID {
            // Register the ID before writing the file: a registered ID whose file is missing
            // is repaired by loadAndRepair at launch, but an unregistered scene file
            // would never be discovered again
            try addSceneIdIfNeeded()
        }
        try data.write(to: url, options: .atomic)
        uniDebugLog("scene saved: " + url.path)
    }

    /// Copies the data into the scene directory and returns the URL of the copy.
    /// Data that already belongs to the scene is used as is.
    public func copyData(fromURL url: URL, newUUID: String = UUID().uuidString) throws -> URL {
        guard !contains(url) else { return url }
        return try copyData(fromURL: url, toId: newUUID)
    }

    /// Copies the data into a file of its own even when it already belongs to the scene, so
    /// that two objects never point at one file: removing either would delete it for both.
    public func duplicateData(at url: URL) throws -> URL {
        try copyData(fromURL: url, toId: UUID().uuidString)
    }

    private func copyData(fromURL url: URL, toId id: String) throws -> URL {
        let destination = dataURL(id: id)
        try FileManager.default.createDirectoryIfNeeded(at: sceneRootURL)
        try FileManager.default.copyItem(at: url, to: destination)
        return destination
    }

    /// Deletes the data only when it belongs to this scene, so a file that is still
    /// referenced at its original location (e.g. `copyData` failed) is never touched.
    public func removeManagedDataIfNeeded(at url: URL) {
        guard contains(url) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Compares path components so that a scene directory isn't confused with
    /// another one that merely shares a prefix (e.g. scene 12 and scene 123).
    private func contains(_ url: URL) -> Bool {
        let root = sceneRootURL.standardizedFileURL.pathComponents
        let target = url.standardizedFileURL.pathComponents
        return target.count > root.count && Array(target.prefix(root.count)) == root
    }

    static func dataId(fromURL url: URL) throws -> UUID {
        try UUID(uuidString: url.lastPathComponent).orThrow(NSError.vcam(message: "dataId:failed to generate UUID"))
    }

    public func dataURL(id: String) -> URL {
        sceneRootURL.appending(path: id)
    }

    public func delete() throws {
        guard FileManager.default.fileExists(atPath: sceneRootURL.path) else { return }
        try FileManager.default.removeItem(at: sceneRootURL)
    }
}

extension VCamSceneDataStore {
    public static func saveSceneOrder(_ loadedSceneIds: [Int32]) throws {
        var metadata = try VCamSceneMetadata.loadOrCreate()
        let loadedSceneIdSet = Set(loadedSceneIds)
        let unavailableSceneIds = metadata.sceneIds.filter {
            !loadedSceneIdSet.contains($0)
                && FileManager.default.fileExists(atPath: URL.scene(sceneId: $0).path)
        }
        metadata.sceneIds = loadedSceneIds + unavailableSceneIds
        try metadata.save()
    }

    public static var defaultObjects: [SceneObject] {
        [
            .init(id: SceneObject.avatarID, type: .avatar(.init()), isHidden: false, isLocked: false)
        ]
    }

    public func makeNewScene() -> VCamScene {
        .init(id: sceneId, name: "", objects: [
            .init(id: SceneObject.avatarID, name: "", type: .avatar(state: .zero), isHidden: false, isLocked: false)
        ], aspectRatio: MainTexture.shared.aspectRatio)
    }

    /// Encoding is all-or-nothing so that an object which can't be converted is never
    /// dropped from an otherwise successfully saved scene.
    public func makeScene(name: String, objects: [SceneObject]) throws -> VCamScene {
        uniDebugLog("makeScene: \(objects.count)")
        return .init(
            id: sceneId,
            name: name,
            objects: try objects.map { try $0.encodeScene() },
            aspectRatio: MainTexture.shared.aspectRatio
        )
    }

    private func addSceneIdIfNeeded() throws {
        var metadata = try VCamSceneMetadata.loadOrCreate()
        if !metadata.sceneIds.contains(sceneId) {
            metadata.sceneIds.append(sceneId)
            try metadata.save()
        }
    }
}

extension VCamSceneDataStore {
    /// Loads every scene while repairing data inconsistencies in a single pass:
    /// skips scenes that can't be loaded, removes image objects whose files are missing,
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
                    case .avatar, .screen, .captureDevice, .web, .text, .wind: ()
                    case let .image(imageId, _):
                        if !FileManager.default.fileExists(atPath: dataStore.dataURL(id: imageId).path) {
                            return nil
                        }
                    }
                    return $0
                }
                // Only rewrite the scene when an invalid object was actually removed.
                // The rewrite is best-effort so a scene stays usable even if it can't be persisted.
                if scene.objects.count != originalCount {
                    do {
                        try dataStore.save(scene)
                    } catch {
                        Logger.error(error)
                    }
                }
                scenes.append(scene)
                validIds.append(id)
            } catch {
                // A scene that fails to load is never deleted, since the failure can be transient.
                // It stays registered so the next launch retries it, and only IDs whose file is
                // already gone are dropped from the metadata.
                Logger.error(error)
                if FileManager.default.fileExists(atPath: dataStore.sceneURL.path) {
                    validIds.append(id)
                }
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
