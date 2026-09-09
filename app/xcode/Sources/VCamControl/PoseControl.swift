import Foundation

/// Pose editing behind an injected provider: the editor lives in the UI
/// layer, which registers its implementation at startup. Bones are named as
/// VRM 1.0 names them (`hips`, `leftUpperArm`, ...), so the API needs no
/// model type of its own.
@MainActor
public enum PoseControl {
    /// The pose of one humanoid bone: its rotation as a delta from the rest
    /// pose in degrees (applied Y, X, Z), and its position for the hips only.
    public struct JointPose: Sendable, Equatable {
        public let bone: String
        public let rotation: SIMD3<Float>
        public let position: SIMD3<Float>?

        public init(bone: String, rotation: SIMD3<Float>, position: SIMD3<Float>? = nil) {
            self.bone = bone
            self.rotation = rotation
            self.position = position
        }
    }

    /// The weight of one expression, named as VRM 1.0 names a preset (`happy`,
    /// `blink`, ...) and as the model names a custom expression.
    public struct ExpressionWeight: Sendable, Equatable {
        public let name: String
        /// 0 to 1
        public let weight: Float

        public init(name: String, weight: Float) {
            self.name = name
            self.weight = weight
        }
    }

    /// What the avatar loaded into the editor can be posed with
    public struct Rig: Sendable, Equatable {
        public let bones: [String]
        public let expressions: [String]

        public init(bones: [String], expressions: [String]) {
            self.bones = bones
            self.expressions = expressions
        }
    }

    /// nil until the UI layer has registered its implementation, and in the
    /// variants that have no pose editor
    public static var provider: (any PoseEditing)?
}

public enum PoseControlError: Error, Sendable, Equatable {
    /// The editor window is not open
    case editorNotOpen
    /// The avatar has no such bone, or the name is not a VRM bone
    case boneNotFound(String)
    /// The avatar has no such expression
    case expressionNotFound(String)
    /// No avatar is loaded, or it could not be loaded into the editor
    case avatarUnavailable
}

/// Every method but `open` and `close` throws `editorNotOpen` until the editor
/// has an avatar loaded, so callers need not track the window's lifecycle.
@MainActor
public protocol PoseEditing: AnyObject {
    /// Opens the editor with the current avatar, fronting it if it is already
    /// open, and returns the bones and expressions the avatar has
    func open() async throws -> PoseControl.Rig
    func close()
    /// Every bone the avatar has, whether posed or not
    func currentPose() throws -> [PoseControl.JointPose]
    /// Applies the given bones as one undoable change; the others stay as they are
    func setPose(_ joints: [PoseControl.JointPose]) throws
    /// Returns the bones to the rest pose, or every bone when `bones` is nil
    func resetPose(bones: [String]?) throws
    /// Every expression the avatar has, whether worn or not
    func currentExpressions() throws -> [PoseControl.ExpressionWeight]
    /// Applies the given weights as one undoable change; the others stay as they are
    func setExpressions(_ expressions: [PoseControl.ExpressionWeight]) throws
    /// Takes the expressions off, or every expression when `names` is nil
    func resetExpressions(names: [String]?) throws
    /// Plays the pose on the live avatar
    func applyToAvatar() async throws
    /// The pose as a `.vrma` holding it for `duration` seconds
    func exportAnimation(name: String, duration: Float) throws -> Data
    /// Registers the pose in the motion library and returns its motion ID
    func addToMotions(name: String, duration: Float, isLoop: Bool) async throws -> String
}
