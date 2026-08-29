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

    private static var didAttemptRestore = false

    /// Whether the app will push a model right after launch, so the engine leaves the
    /// avatar empty instead of restoring one of its own
    public static var hasPendingRestore: Bool {
        ModelManager.shared.lastLoadedModel?.status == .valid
    }

    /// Loads the model that was in use when the app last quit. The library keeps its own
    /// copy of every model, so nothing else has to be cached for this
    public static func restoreLastModelOnLaunch(modelManager: ModelManager = .shared) {
        guard !didAttemptRestore else { return }
        didAttemptRestore = true

        guard let item = modelManager.lastLoadedModel, item.status == .valid else { return }
        do {
            try load(item, modelManager: modelManager)
        } catch {
            Logger.error(error)
        }
    }

    /// Loads a registered model and records it as the last loaded one.
    /// The avatar is no longer the VRoid Hub one, so that reference is cleared
    public static func load(_ item: ModelItem, modelManager: ModelManager = .shared) throws {
        guard item.status == .valid else { return }
        VRoidModelReference.lastUsed = nil
#if FEATURE_3
        UniBridge.loadVRM(path: item.model.modelURL.path)
#else
        UniBridge.shared.loadModel(item.model.modelURL.path)
#endif
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
