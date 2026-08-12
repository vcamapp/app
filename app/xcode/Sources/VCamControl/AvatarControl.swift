import Foundation
import VCamBridge
import VCamData

/// Avatar loading operations shared by the model list, drag & drop, and other entry points
@MainActor
public enum AvatarControl {
    /// Loads a registered model and records it as the last loaded one
    public static func load(_ item: ModelItem, modelManager: ModelManager = .shared) throws {
        guard item.status == .valid else { return }
#if FEATURE_3
        load(vrmFileURL: item.model.modelURL)
#else
        load(modelDirectoryURL: item.model.modelURL)
#endif
        try modelManager.setLastLoadedModel(item)
    }

    /// Loads a VRM file directly without registering it to the model library
    public static func load(vrmFileURL: URL) {
        UniBridge.shared.loadVRM(vrmFileURL.path)
    }

#if !FEATURE_3
    /// Loads a model directory directly without registering it to the model library
    public static func load(modelDirectoryURL: URL) {
        UniBridge.shared.loadModel(modelDirectoryURL.path)
    }
#endif
}
