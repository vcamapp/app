import Foundation

/// Scene operations behind an injected provider: the scene machinery lives
/// in the UI layer, which registers its implementation at startup.
@MainActor
public enum SceneControl {
    public struct Scene: Sendable {
        public let id: Int32
        public let name: String

        public init(id: Int32, name: String) {
            self.id = id
            self.name = name
        }
    }

    /// nil until the UI layer has registered its implementation
    public static var provider: (any SceneControlling)?
}

@MainActor
public protocol SceneControlling: AnyObject {
    var sceneList: [SceneControl.Scene] { get }
    var activeScene: SceneControl.Scene? { get }
    func loadScene(id: Int32) async throws
}
