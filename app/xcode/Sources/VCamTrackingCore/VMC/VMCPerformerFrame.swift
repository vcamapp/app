import SIMDCompat

/// A humanoid bone of the VMC Protocol, named as `HumanBodyBones` spells it and in its order
public enum VMCBone: String, CaseIterable, Sendable {
    case hips = "Hips"
    case leftUpperLeg = "LeftUpperLeg"
    case rightUpperLeg = "RightUpperLeg"
    case leftLowerLeg = "LeftLowerLeg"
    case rightLowerLeg = "RightLowerLeg"
    case leftFoot = "LeftFoot"
    case rightFoot = "RightFoot"
    case spine = "Spine"
    case chest = "Chest"
    case neck = "Neck"
    case head = "Head"
    case leftShoulder = "LeftShoulder"
    case rightShoulder = "RightShoulder"
    case leftUpperArm = "LeftUpperArm"
    case rightUpperArm = "RightUpperArm"
    case leftLowerArm = "LeftLowerArm"
    case rightLowerArm = "RightLowerArm"
    case leftHand = "LeftHand"
    case rightHand = "RightHand"
    case leftToes = "LeftToes"
    case rightToes = "RightToes"
    case leftEye = "LeftEye"
    case rightEye = "RightEye"
    case jaw = "Jaw"
    case leftThumbProximal = "LeftThumbProximal"
    case leftThumbIntermediate = "LeftThumbIntermediate"
    case leftThumbDistal = "LeftThumbDistal"
    case leftIndexProximal = "LeftIndexProximal"
    case leftIndexIntermediate = "LeftIndexIntermediate"
    case leftIndexDistal = "LeftIndexDistal"
    case leftMiddleProximal = "LeftMiddleProximal"
    case leftMiddleIntermediate = "LeftMiddleIntermediate"
    case leftMiddleDistal = "LeftMiddleDistal"
    case leftRingProximal = "LeftRingProximal"
    case leftRingIntermediate = "LeftRingIntermediate"
    case leftRingDistal = "LeftRingDistal"
    case leftLittleProximal = "LeftLittleProximal"
    case leftLittleIntermediate = "LeftLittleIntermediate"
    case leftLittleDistal = "LeftLittleDistal"
    case rightThumbProximal = "RightThumbProximal"
    case rightThumbIntermediate = "RightThumbIntermediate"
    case rightThumbDistal = "RightThumbDistal"
    case rightIndexProximal = "RightIndexProximal"
    case rightIndexIntermediate = "RightIndexIntermediate"
    case rightIndexDistal = "RightIndexDistal"
    case rightMiddleProximal = "RightMiddleProximal"
    case rightMiddleIntermediate = "RightMiddleIntermediate"
    case rightMiddleDistal = "RightMiddleDistal"
    case rightRingProximal = "RightRingProximal"
    case rightRingIntermediate = "RightRingIntermediate"
    case rightRingDistal = "RightRingDistal"
    case rightLittleProximal = "RightLittleProximal"
    case rightLittleIntermediate = "RightLittleIntermediate"
    case rightLittleDistal = "RightLittleDistal"
    case upperChest = "UpperChest"
}

/// What a VMC Protocol performer last sent, at one moment
public struct VMCPerformerFrame: Sendable {
    /// In the performer's avatar space: +Z is forward and +X is the avatar's own right, left-handed
    public struct Transform: Equatable, Sendable {
        public var position: SIMD3<Float>
        public var rotation: simd_quatf

        public init(position: SIMD3<Float>, rotation: simd_quatf) {
            self.position = position
            self.rotation = rotation
        }
    }

    /// The avatar's origin (`/VMC/Ext/Root/Pos`), nil until the performer sends it
    public var root: Transform?
    /// The bones the performer has sent: the rotation of each bone normalized to zero in the T-pose, from its parent
    /// bone, and its position from its parent node (the hips from the avatar's origin)
    public var bones: [VMCBone: Transform]
    /// The weights by the names the performer uses, as of its last `/VMC/Ext/Blend/Apply`.
    /// nil while the performer sends none, or the receiver is set to leave the face alone
    public var expressions: [String: Float]?

    public init(root: Transform? = nil, bones: [VMCBone: Transform], expressions: [String: Float]? = nil) {
        self.root = root
        self.bones = bones
        self.expressions = expressions
    }
}
