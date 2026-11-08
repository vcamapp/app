import Foundation
import VCamBridge
import VCamData
import VCamLogger

@MainActor
public enum AvatarControl {
    /// Notifies the API layer when an avatar has finished loading; nil for avatars
    /// that are not in the model library
    public static var onLoad: ((UUID?) -> Void)?

    private static var loadsInProgress: [UUID?] = []

    /// The renderer calls this when a load has ended, whatever asked for it. A load nobody
    /// asked for through here, such as the app's default avatar, is one outside the library.
    public static func didFinishLoading(succeeded: Bool) {
        let avatarId = loadsInProgress.isEmpty ? nil : loadsInProgress.removeFirst()
        if succeeded {
            onLoad?(avatarId)
        }
    }

    /// Only for a listener, since the engine path that has no listener never reports the end
    private static func noteLoadStarted(_ avatarId: UUID?) {
        if onLoad != nil {
            loadsInProgress.append(avatarId)
        }
    }

    /// Whether the app will push a model right after launch; see ``LaunchAvatarRestore``
    public static var hasPendingRestore: Bool {
        ModelManager.shared.restorableLastLoadedModel != nil
    }

    /// ``LaunchAvatarRestore`` guarantees this runs at most once per launch
    public static func restoreLastModelOnLaunch() {
        guard let item = ModelManager.shared.restorableLastLoadedModel else { return }
        do {
            try load(item)
        } catch {
            Logger.error(error)
        }
    }

    /// The engine reports nothing back for its launch load, so the bookkeeping of
    /// ``load(_:modelManager:)`` happens here.
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

    /// Finishes when the avatar is in place, so that what is asked next reads the new one
    public static func loadAndWait(_ item: ModelItem, modelManager: ModelManager = .shared) async throws {
        guard item.status == .valid else { return }
        noteLoadStarted(item.id)
#if FEATURE_3
        try await UniBridge.loadVRM(path: item.model.modelURL.path(percentEncoded: false), source: .file)
#else
        UniBridge.shared.loadModel(item.model.modelURL.path(percentEncoded: false))
#endif
        try recordLoad(of: item, modelManager: modelManager)
    }

    public static func load(_ item: ModelItem, modelManager: ModelManager = .shared) throws {
        guard item.status == .valid else { return }
        noteLoadStarted(item.id)
#if FEATURE_3
        UniBridge.loadVRM(path: item.model.modelURL.path(percentEncoded: false))
#else
        UniBridge.shared.loadModel(item.model.modelURL.path(percentEncoded: false))
#endif
        try recordLoad(of: item, modelManager: modelManager)
    }

    /// The avatar is no longer the VRoid Hub one, so that reference is cleared
    private static func recordLoad(of item: ModelItem, modelManager: ModelManager) throws {
        Logger.log(event: .loadModelFile)
        VRoidModelReference.lastUsed = nil
        try modelManager.setLastLoadedModel(item)
    }

#if FEATURE_3
    /// Loads a VRoid Hub model from a temporary plaintext VRM, which the engine neither persists
    /// nor allows exporting. The stored VRoid reference is left untouched so a transient failure can be retried
    public static func load(vroidModelFileURL: URL) async throws {
        noteLoadStarted(nil)
        try await UniBridge.loadVRM(path: vroidModelFileURL.path(percentEncoded: false), source: .vroidHub)
    }
#endif
}
