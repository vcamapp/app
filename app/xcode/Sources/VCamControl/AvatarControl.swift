import Foundation
import VCamBridge
import VCamData
import VCamLogger

/// Avatar loading operations shared by the model list, drag & drop, and other entry points
@MainActor
public enum AvatarControl {
    /// Notifies the API layer of load requests; nil for loads whose avatar is
    /// not in the model library
    public static var onLoad: ((UUID?) -> Void)?

    /// Whether the app will push a model right after launch; see ``LaunchAvatarRestore``
    public static var hasPendingRestore: Bool {
        ModelManager.shared.restorableLastLoadedModel != nil
    }

    /// Loads the model that was in use when the app last quit. The library keeps its own
    /// copy of every model, so nothing else has to be cached for this.
    /// ``LaunchAvatarRestore`` guarantees this runs at most once per launch
    public static func restoreLastModelOnLaunch() {
        guard let item = ModelManager.shared.restorableLastLoadedModel else { return }
        do {
            try load(item)
        } catch {
            Logger.error(error)
        }
    }

    /// Hands the model that was in use when the app last quit to the engine, which loads it
    /// in its first scene. The engine reports nothing back for that load, so the bookkeeping
    /// of ``load(_:modelManager:)`` happens here.
    /// ``LaunchAvatarRestore`` guarantees this runs at most once per launch
    public static func takeLastModelFileForEngineLaunchLoad(modelManager: ModelManager = .shared) -> URL? {
        guard let item = modelManager.restorableLastLoadedModel else { return nil }
        do {
            try recordLoad(of: item, modelManager: modelManager)
        } catch {
            Logger.error(error)
        }
        return item.model.modelURL
    }

    /// Loads a registered model and records it as the last loaded one
    public static func load(_ item: ModelItem, modelManager: ModelManager = .shared) throws {
        guard item.status == .valid else { return }
#if FEATURE_3
        UniBridge.loadVRM(path: item.model.modelURL.path)
#else
        UniBridge.shared.loadModel(item.model.modelURL.path)
#endif
        try recordLoad(of: item, modelManager: modelManager)
    }

    /// The avatar is no longer the VRoid Hub one, so that reference is cleared
    private static func recordLoad(of item: ModelItem, modelManager: ModelManager) throws {
        Logger.log(event: .loadModelFile)
        VRoidModelReference.lastUsed = nil
        onLoad?(item.id)
        try modelManager.setLastLoadedModel(item)
    }

#if FEATURE_3
    /// Loads a VRoid Hub model from a temporary plaintext VRM and waits for the load result.
    /// The engine neither persists the file nor allows exporting the avatar for this source.
    /// The stored VRoid reference is left untouched so a transient failure can be retried
    public static func load(vroidModelFileURL: URL) async throws {
        onLoad?(nil)
        try await UniBridge.loadVRM(path: vroidModelFileURL.path, source: .vroidHub)
    }
#endif
}
