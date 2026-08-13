import Foundation
import VCamBridge
import VCamData

/// Avatar loading operations shared by the model list, drag & drop, and other entry points
@MainActor
public enum AvatarControl {
    /// Notifies the API layer of load requests; nil for direct file loads
    /// that bypass the avatar library
    public static var onLoad: ((UUID?) -> Void)?

    /// Loads a registered model and records it as the last loaded one
    public static func load(_ item: ModelItem, modelManager: ModelManager = .shared) throws {
        guard item.status == .valid else { return }
#if FEATURE_3
        requestLoad(fileURL: item.model.modelURL)
#else
        requestLoad(directoryURL: item.model.modelURL)
#endif
        onLoad?(item.id)
        try modelManager.setLastLoadedModel(item)
    }

    /// Loads a VRM file directly without registering it to the model library
    public static func load(vrmFileURL: URL) {
        requestLoad(fileURL: vrmFileURL)
        onLoad?(nil)
    }

    private static func requestLoad(fileURL: URL) {
        UniBridge.shared.loadVRM(fileURL.path)
    }

#if !FEATURE_3
    /// Loads a model directory directly without registering it to the model library
    public static func load(modelDirectoryURL: URL) {
        requestLoad(directoryURL: modelDirectoryURL)
        onLoad?(nil)
    }

    private static func requestLoad(directoryURL: URL) {
        UniBridge.shared.loadModel(directoryURL.path)
    }
#endif
}
