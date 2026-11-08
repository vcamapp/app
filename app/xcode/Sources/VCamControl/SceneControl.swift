import Foundation
import VCamEntity

public enum SceneControlError: Error {
    case notFound
    case notRemovable
}

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
    /// nil in apps that can't crossfade, which switch scenes at once
    public static var transition: (any SceneTransitionPresenting)?

    /// The objects of a scene are drawn in the frames after it loads, so the crossfade starts
    /// once they have had the time to show up behind the held frame
    private static let transitionSettleDelay = Duration.milliseconds(100)
    private static let transitionSlot = AnimationSlot()
    private static var transitionGeneration = 0

    /// Finishes when the new scene is fully on screen, or when another load takes over
    public static func loadScene(id: Int32, animation: ControlAnimation?, on provider: any SceneControlling) async throws {
        transitionGeneration &+= 1
        let generation = transitionGeneration
        transitionSlot.cancel()

        // Held without an animation too, since the parts of a scene show up over several frames
        guard let transition, transition.holdCurrentFrame() else {
            transition?.releaseHeldFrame()
            try await provider.loadScene(id: id)
            return
        }

        do {
            try await provider.loadScene(id: id)
        } catch {
            transition.releaseHeldFrame()
            throw error
        }
        guard let animation else {
            if generation == transitionGeneration {
                transition.releaseHeldFrame()
            }
            return
        }
        try? await Task.sleep(for: transitionSettleDelay)
        guard generation == transitionGeneration else { return }

        let finished = await transitionSlot.run(animation) { progress in
            transition.setHeldFrameOpacity(Float(1 - progress))
        }
        if finished {
            transition.releaseHeldFrame()
        }
    }
}

/// Keeps the frame on screen over whatever is drawn after it, in the compositor
@MainActor
public protocol SceneTransitionPresenting: AnyObject {
    /// false when there is no frame to hold yet
    func holdCurrentFrame() -> Bool
    func setHeldFrameOpacity(_ opacity: Float)
    func releaseHeldFrame()
}

@MainActor
public protocol SceneControlling: AnyObject {
    var sceneList: [SceneControl.Scene] { get }
    var activeScene: SceneControl.Scene? { get }
    /// nil while the current scene uses the renderer's default light
    var lighting: VCamScene.Lighting? { get }
    func loadScene(id: Int32) async throws
    /// Loads the new scene
    func createScene(name: String?) async throws -> SceneControl.Scene
    func duplicateScene(id: Int32, name: String?) async throws -> SceneControl.Scene
    func renameScene(id: Int32, name: String) throws
    func moveScene(id: Int32, toIndex index: Int) throws
    func removeScene(id: Int32) async throws
    func setLighting(_ lighting: VCamScene.Lighting?) throws
}
