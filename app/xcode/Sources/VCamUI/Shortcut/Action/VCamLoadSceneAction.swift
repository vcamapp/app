import Foundation
import VCamEntity
import struct SwiftUI.Image

public struct VCamLoadSceneAction: VCamAction {
    public init(configuration: VCamLoadSceneActionConfiguration) {
        self.configuration = configuration
    }

    public var configuration: VCamLoadSceneActionConfiguration
    public var name: String { String(localized: .loadScene) }
    public var icon: Image { Image(systemName: "square.3.stack.3d.top.fill") }

    @MainActor
    public func callAsFunction(context: VCamActionContext) async throws {
        try? SceneManager.shared.loadScene(id: configuration.sceneId)
    }
}
