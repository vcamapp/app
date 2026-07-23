import SwiftUI
import VCamEntity
import VCamBridge
import VCamData
import VCamLogger

@MainActor
@Observable
public final class SceneManager {
    public static let shared = SceneManager()

    public private(set) var currentSceneId: Int32

    @ObservationIgnored var currentScene: VCamScene {
        get throws {
            try scenes.find(byId: currentSceneId).orThrow(NSError.vcam(message: "invalid scene id: \(currentSceneId)"))
        }
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
            (loadedScenes, _) = try VCamSceneDataStore.loadAndRepair(metadata: metadata)
        } catch {
            uniDebugLog(error.localizedDescription)
            loadedScenes = []
        }

        var landscape = loadedScenes.scenes(isLandscape: true)
        var portrait = loadedScenes.scenes(isLandscape: false)
        if landscape.isEmpty {
            landscape = [Self.createAndSaveNewScene()]
        }
        if portrait.isEmpty {
            portrait = [Self.createAndSaveNewScene()]
        }
        self.scenesByOrientation = OrientedScenes(landscape: landscape, portrait: portrait)
        let currentScenes = MainTexture.shared.isLandscape ? landscape : portrait
        self.currentSceneId = currentScenes[0].id
    }

    private static func createNewScene(sceneId: Int32 = .random(in: 0..<Int32.max)) -> VCamScene {
        let dataStore = VCamSceneDataStore(sceneId: sceneId)
        return dataStore.makeNewScene()
    }

    private static func createAndSaveNewScene() -> VCamScene {
        let scene = createNewScene()
        try? VCamSceneDataStore(sceneId: scene.id).save(scene)
        return scene
    }

    public func addNewScene() throws {
        let scene = Self.createNewScene()
        try add(scene)
        try loadScene(id: scene.id)
    }

    public func add(_ scene: VCamScene) throws {
        Logger.log("")
        let dataStore = VCamSceneDataStore(sceneId: scene.id)
        try dataStore.save(scene)
        scenes.append(scene)
    }

    public func update(_ scene: VCamScene) {
        guard let index = scenes.index(ofId: scene.id) else {
            return
        }
        scenes[index] = scene
    }

    public func remove(byId id: Int32) {
        guard let scene = scenes.find(byId: id) else {
            return
        }
        remove(scene)
    }

    private func remove(_ scene: VCamScene) {
        scenes.remove(byId: scene.id)
        try? VCamSceneDataStore(sceneId: scene.id).delete()
        try? save()
        if currentSceneId == scene.id, let nextScene = scenes.first {
            try? loadScene(id: nextScene.id)
        } else {
            try? saveCurrentSceneAndObjects()
        }
    }

    public func move(byId id: Int32, up: Bool) {
        guard let index = scenes.index(ofId: id) else {
            return
        }

        let destination = index + (up ? 1 : -1)
        if 0 <= destination && destination < scenes.count {
            scenes.swapAt(index, destination)
            try? save()
        }
    }

    public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        scenes.move(fromOffsets: source, toOffset: destination)
        try? save()
    }

    public func loadScene(id: Int32) throws {
        if currentSceneId != id {
            try? saveCurrentSceneAndObjects() // Save when switching scenes
        }
        let scene = try scenes.find(byId: id).orThrow(NSError.vcam(message: "invalid scene id: \(id)"))
        uniDebugLog("\(scene.id) \(scene.objects.count)")
        Logger.log("\(scene.id) \(scene.objects.count)")
        currentSceneId = id
        Task {
            await SceneObjectManager.shared.loadObjects(scene)
        }
    }

    public func loadCurrentScene() throws {
        try loadScene(id: currentSceneId)
    }

    public func saveCurrentSceneAndObjects() throws {
        let dataStore = VCamSceneDataStore(sceneId: currentSceneId)
        let scene = try dataStore.makeScene(name: currentScene.name, objects: SceneObjectManager.shared.objects)
        try dataStore.save(scene)
        update(scene)
    }

    private func save() throws {
        var metadata = VCamSceneMetadata.loadOrCreate()
        metadata.sceneIds = (scenesByOrientation.landscape + scenesByOrientation.portrait).map(\.id)
        try metadata.save()
    }

    func changeAspectRatio() {
        // The aspect-ratio flag is already toggled, so `scenes` now reflects the new
        // orientation automatically (edits were always written to the backing store).
        guard let scene = scenes.first else { return }
        UniBridge.shared.resetAllObjects() // Since processing is delayed, first remove only the list items from UI.
        Task { @MainActor in
            // Unity doesn't notify when the canvas finishes resizing, so poll until its
            // orientation matches instead of waiting a fixed time; time out as a fallback.
            let isLandscape = MainTexture.shared.isLandscape
            for _ in 0..<40 {
                let canvasSize = UniBridge.shared.canvasCGSize
                if (canvasSize.width >= canvasSize.height) == isLandscape { break }
                try? await Task.sleep(for: .milliseconds(50))
            }
            try? self.loadScene(id: scene.id)
        }
    }
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
