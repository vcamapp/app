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

    public var scenes: [VCamScene]
    @ObservationIgnored private var landScapeScenes: [VCamScene]
    @ObservationIgnored private var portraitScenes: [VCamScene]

    private init() {
        let newSceneId = Int32.random(in: 0..<Int32.max)

        NotificationCenter.default.addObserver(
            forName: .aspectRatioDidChange,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                SceneManager.shared.changeAspectRatio()
            }
        }

        do {
            var metadata = try VCamSceneMetadata.load()
            metadata = try VCamSceneDataStore.clean(metadata: metadata)
            let scenes: [VCamScene] = metadata.sceneIds
                .map(VCamSceneDataStore.init(sceneId:))
                .compactMap { dataStore in
                    do {
                        return try dataStore.load()
                    } catch {
                        // Scenes that couldn't be loaded are deleted.
                        uniDebugLog("Delete scene: \(dataStore.sceneId)")
                        try? dataStore.delete()
                        metadata.remove(sceneId: dataStore.sceneId)
                        try? metadata.save()
                        return nil
                    }
                }
            self.landScapeScenes = scenes.scenes(isLandscape: true)
            self.portraitScenes = scenes.scenes(isLandscape: false)
            self.landScapeScenes = self.landScapeScenes.isEmpty ? [Self.createNewScene()] : self.landScapeScenes
            self.portraitScenes = self.portraitScenes.isEmpty ? [Self.createNewScene()] : self.portraitScenes
            let currentScenes = MainTexture.shared.isLandscape ? self.landScapeScenes : self.portraitScenes
            self.scenes = currentScenes
            self.currentSceneId = currentScenes.first?.id ?? newSceneId
        } catch {
            uniDebugLog(error.localizedDescription)
            let dataStore = VCamSceneDataStore(sceneId: newSceneId)
            let scene = dataStore.makeNewScene()
            self.landScapeScenes = [scene]
            self.portraitScenes = [scene]
            self.scenes = MainTexture.shared.isLandscape ? self.landScapeScenes : self.portraitScenes
            self.currentSceneId = newSceneId
            try? dataStore.save(scene)
        }
    }

    private static func createNewScene(sceneId: Int32 = .random(in: 0..<Int32.max)) -> VCamScene {
        let dataStore = VCamSceneDataStore(sceneId: sceneId)
        return dataStore.makeNewScene()
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
        SceneObjectManager.shared.loadObjects(scene)
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
        if MainTexture.shared.isLandscape {
            landScapeScenes = scenes
        } else {
            portraitScenes = scenes
        }
        metadata.sceneIds = (landScapeScenes + portraitScenes).map(\.id)
        try metadata.save()
    }

    func changeAspectRatio() {
        // Store the previous state in memory
        // (since the flag is already toggled, store it in the reversed state)
        if MainTexture.shared.isLandscape {
            portraitScenes = scenes
        } else {
            landScapeScenes = scenes
        }
        scenes = MainTexture.shared.isLandscape ? landScapeScenes : portraitScenes
        
        if let scene = scenes.first {
            UniBridge.shared.resetAllObjects() // Since processing is delayed, first remove only the list items from UI.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(800))
                // A slight delay is needed until the canvas size aspect ratio changes (TODO: investigation required).
                try? self.loadScene(id: scene.id)
            }
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
