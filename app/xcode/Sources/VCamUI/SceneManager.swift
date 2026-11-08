import SwiftUI
import VCamEntity
import VCamBridge
import VCamControl
import VCamData
import VCamLogger

@MainActor
@Observable
public final class SceneManager {
    public static let shared = SceneManager()

    private var selectedSceneId: Int32

    /// Always a scene of the current orientation: right after the orientation flips, the selection
    /// still refers to a scene of the previous one until `changeAspectRatio` finishes loading.
    var currentScene: VCamScene {
        scenes.find(byId: selectedSceneId) ?? scenes[0]
    }

    public var currentSceneId: Int32 { currentScene.id }

    /// nil until the user changes it, so the renderer's default applies
    public var currentLighting: VCamScene.Lighting? {
        currentScene.lighting
    }

    /// Changes only what is in memory, so a value that follows a drag can be saved once at the end
    /// with ``saveCurrentSceneAndObjects()``
    public func setCurrentLighting(_ lighting: VCamScene.Lighting?) {
        guard let index = scenes.index(ofId: currentSceneId) else { return }
        scenes[index].lighting = lighting
    }

    /// Scenes are kept per orientation so each keeps its own order.
    /// Both orientations always hold at least one scene by construction.
    private struct OrientedScenes {
        var landscape: [VCamScene]
        var portrait: [VCamScene]

        subscript(isLandscape isLandscape: Bool) -> [VCamScene] {
            get { isLandscape ? landscape : portrait }
            set {
                if isLandscape {
                    landscape = newValue
                } else {
                    portrait = newValue
                }
            }
        }
    }

    private var scenesByOrientation: OrientedScenes
    // The slice for the current orientation, so the working copy never drifts from the backing store.
    public var scenes: [VCamScene] {
        get { scenesByOrientation[isLandscape: MainTexture.shared.isLandscape] }
        set { scenesByOrientation[isLandscape: MainTexture.shared.isLandscape] = newValue }
    }

    private init() {
        NotificationCenter.default.addObserver(
            forName: .aspectRatioDidChange,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                SceneManager.shared.changeAspectRatio()
            }
        }

        // Even when loading fails, fall back to empty and create default scenes below,
        // so both orientations are always populated with distinct scene IDs.
        let loadedScenes: [VCamScene]
        do {
            let metadata = try VCamSceneMetadata.load()
            let repaired = try VCamSceneDataStore.loadAndRepair(metadata: metadata)
            loadedScenes = repaired.scenes
        } catch {
            uniDebugLog(error.localizedDescription)
            loadedScenes = []
        }

        var landscape = loadedScenes.scenes(isLandscape: true)
        var portrait = loadedScenes.scenes(isLandscape: false)
        if landscape.isEmpty {
            landscape = [Self.createAndSaveNewScene(isLandscape: true)]
        }
        if portrait.isEmpty {
            portrait = [Self.createAndSaveNewScene(isLandscape: false)]
        }
        let orientedScenes = OrientedScenes(landscape: landscape, portrait: portrait)
        // The output size follows the persisted resolution, which UniState applies on creation.
        // Make sure that happened before reading the orientation.
        _ = UniState.shared
        self.scenesByOrientation = orientedScenes
        self.selectedSceneId = orientedScenes[isLandscape: MainTexture.shared.isLandscape][0].id
    }

    private static func createNewScene(isLandscape: Bool) -> VCamScene {
        let dataStore = VCamSceneDataStore(sceneId: .random(in: 0..<Int32.max))
        return dataStore.makeNewScene(isLandscape: isLandscape)
    }

    private static func createAndSaveNewScene(isLandscape: Bool) -> VCamScene {
        let scene = createNewScene(isLandscape: isLandscape)
        do {
            try VCamSceneDataStore(sceneId: scene.id).saveNew(scene)
        } catch {
            // The ID is registered before the file is written, so a failure here leaves an ID without data
            Logger.error(error)
        }
        return scene
    }

    @discardableResult
    public func addNewScene() async throws -> VCamScene {
        let scene = Self.createNewScene(isLandscape: MainTexture.shared.isLandscape)
        try add(scene)
        try await loadScene(id: scene.id)
        return scene
    }

    public func add(_ scene: VCamScene) throws {
        Logger.log("")
        let dataStore = VCamSceneDataStore(sceneId: scene.id)
        try dataStore.saveNew(scene)
        scenes.append(scene)
    }

    @discardableResult
    public func duplicate(_ scene: VCamScene) async throws -> VCamScene {
        var duplicatedScene = scene
        duplicatedScene.id = Int32.random(in: 0..<Int32.max)
        let sourceSceneID = scene.id
        let duplicatedSceneID = duplicatedScene.id
        let dataIDs: [String] = scene.objects.compactMap { object -> String? in
            switch object.type {
            case let .image(id, _), let .video(id, _): id
            default: nil
            }
        }

        do {
            try await Self.copyData(dataIDs, fromScene: sourceSceneID, toScene: duplicatedSceneID)
            try add(duplicatedScene)
        } catch {
            await Self.deleteSceneData(sceneID: duplicatedSceneID)
            throw error
        }
        return duplicatedScene
    }

    @concurrent
    private nonisolated static func copyData(_ dataIDs: [String], fromScene sourceSceneID: Int32, toScene destinationSceneID: Int32) async throws {
        let sourceDataStore = VCamSceneDataStore(sceneId: sourceSceneID)
        let destinationDataStore = VCamSceneDataStore(sceneId: destinationSceneID)
        for dataID in dataIDs {
            _ = try destinationDataStore.copyData(
                fromURL: sourceDataStore.dataURL(id: dataID),
                newUUID: dataID
            )
        }
    }

    @concurrent
    private nonisolated static func deleteSceneData(sceneID: Int32) async {
        try? VCamSceneDataStore(sceneId: sceneID).delete()
    }

    public func update(_ scene: VCamScene) {
        guard let index = scenes.index(ofId: scene.id) else {
            return
        }
        scenes[index] = scene
    }

    /// Each orientation must always keep at least one scene, so the last one can't be removed.
    public func remove(byId id: Int32) async {
        guard scenes.count > 1, let scene = scenes.find(byId: id) else {
            return
        }
        // Delete the directory before dropping the scene from memory and metadata; otherwise a
        // failed deletion leaves a directory no launch can ever clean up (loadAndRepair only
        // scans IDs registered in the metadata). The reverse order is repaired at startup.
        do {
            try VCamSceneDataStore(sceneId: scene.id).delete()
        } catch {
            Logger.error(error)
            return
        }
        scenes.remove(byId: scene.id)
        logAnyError { try save() }
        if selectedSceneId == scene.id {
            try? await loadCurrentScene()
        } else {
            logAnyError { try saveCurrentSceneAndObjects() }
        }
    }

    public func move(byId id: Int32, up: Bool) {
        if scenes.move(byId: id, up: up) {
            logAnyError { try save() }
        }
    }

    public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        scenes.move(fromOffsets: source, toOffset: destination)
        logAnyError { try save() }
    }

    /// Persistence failures here can't be recovered by the caller, but they must not be silent
    private func logAnyError(_ body: () throws -> Void) {
        do {
            try body()
        } catch {
            Logger.error(error)
        }
    }

    public func loadScene(id: Int32) async throws {
        // Abort the switch when saving fails so the current scene's edits are not lost.
        // The current scene no longer exists right after its removal; nothing to save then.
        if selectedSceneId != id, scenes.find(byId: selectedSceneId) != nil {
            try saveCurrentSceneAndObjects()
        }
        let scene = try scenes.find(byId: id).orThrow(NSError.vcam(message: "invalid scene id: \(id)"))
        uniDebugLog("\(scene.id) \(scene.objects.count)")
        Logger.log("\(scene.id) \(scene.objects.count)")
        selectedSceneId = id
        await SceneObjectManager.shared.loadObjects(scene)
    }

    public func loadCurrentScene() async throws {
        try await loadScene(id: currentSceneId)
    }

    public func saveCurrentSceneAndObjects() throws {
        // The object list is empty while a scene loads, so saving then would drop every object of the scene
        guard !SceneObjectManager.shared.isLoading else { return }
        // Object edits reach the subtitle too, which persists outside the scene
        SubtitleTextObject.persistStyle()
        try saveCurrentScene(objects: SceneObjectManager.shared.objects)
    }

    /// Callers can save a new object list before applying it to memory, so a failed save
    /// changes nothing.
    public func saveCurrentScene(objects: [SceneObject]) throws {
        let dataStore = VCamSceneDataStore(sceneId: currentSceneId)
        let scene = try dataStore.makeScene(updating: currentScene, objects: objects)
        try dataStore.save(scene)
        update(scene)
    }

    private func save() throws {
        let loadedIds = (scenesByOrientation.landscape + scenesByOrientation.portrait).map(\.id)
        try VCamSceneDataStore.saveSceneOrder(loadedIds)
    }

    func changeAspectRatio() {
        // The aspect-ratio flag is already toggled, so `scenes` now reflects the new orientation
        guard let scene = scenes.first else { return }
        Task { @MainActor in
            try? await self.loadScene(id: scene.id)
        }
    }
}

extension SceneManager: SceneControlling {
    public var sceneList: [SceneControl.Scene] {
        scenes.map { .init(id: $0.id, name: $0.name) }
    }

    public var activeScene: SceneControl.Scene? {
        let scene = currentScene
        return .init(id: scene.id, name: scene.name)
    }

    public func createScene(name: String?) async throws -> SceneControl.Scene {
        let scene = try await addNewScene()
        guard let name else { return .init(id: scene.id, name: scene.name) }
        try renameScene(id: scene.id, name: name)
        return .init(id: scene.id, name: name)
    }

    public func duplicateScene(id: Int32, name: String?) async throws -> SceneControl.Scene {
        let source = try scenes.find(byId: id).orThrow(SceneControlError.notFound)
        let scene = try await duplicate(source)
        guard let name else { return .init(id: scene.id, name: scene.name) }
        try renameScene(id: scene.id, name: name)
        return .init(id: scene.id, name: name)
    }

    public func renameScene(id: Int32, name: String) throws {
        var scene = try scenes.find(byId: id).orThrow(SceneControlError.notFound)
        scene.name = name
        // Unlike the list row, which edits the selected scene, this can reach any scene
        try VCamSceneDataStore(sceneId: id).save(scene)
        update(scene)
    }

    public func moveScene(id: Int32, toIndex index: Int) throws {
        let source = try scenes.index(ofId: id).orThrow(SceneControlError.notFound)
        let target = min(max(index, 0), scenes.count - 1)
        move(fromOffsets: IndexSet(integer: source), toOffset: target > source ? target + 1 : target)
    }

    public func removeScene(id: Int32) async throws {
        guard scenes.find(byId: id) != nil else { throw SceneControlError.notFound }
        guard scenes.count > 1 else { throw SceneControlError.notRemovable }
        await remove(byId: id)
    }

    public func setLighting(_ lighting: VCamScene.Lighting?) throws {
        setCurrentLighting(lighting)
        try saveCurrentSceneAndObjects()
    }

    public var lighting: VCamScene.Lighting? { currentLighting }
}

private extension Array where Element == VCamScene {
    func scenes(isLandscape: Bool) -> Self {
        return filter {
            guard let aspectRatio = $0.aspectRatio else {
                return isLandscape
            }
            if isLandscape {
                return aspectRatio <= 1
            } else {
                return aspectRatio > 1
            }
        }
    }
}
