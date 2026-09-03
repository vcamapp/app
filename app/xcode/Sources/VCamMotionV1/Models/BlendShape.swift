import Foundation

public struct BlendShape: Equatable, Sendable {
    public var lookAtPoint: SIMD2<Float> = .zero
    public var browDownLeft: Float = 0
    public var browDownRight: Float = 0
    public var browInnerUp: Float = 0
    public var browOuterUpLeft: Float = 0
    public var browOuterUpRight: Float = 0
    public var cheekPuff: Float = 0
    public var cheekSquintLeft: Float = 0
    public var cheekSquintRight: Float = 0
    public var eyeBlinkLeft: Float = 0
    public var eyeBlinkRight: Float = 0
    public var eyeLookDownLeft: Float = 0
    public var eyeLookDownRight: Float = 0
    public var eyeLookInLeft: Float = 0
    public var eyeLookInRight: Float = 0
    public var eyeLookOutLeft: Float = 0
    public var eyeLookOutRight: Float = 0
    public var eyeLookUpLeft: Float = 0
    public var eyeLookUpRight: Float = 0
    public var eyeSquintLeft: Float = 0
    public var eyeSquintRight: Float = 0
    public var eyeWideLeft: Float = 0
    public var eyeWideRight: Float = 0
    public var jawForward: Float = 0
    public var jawLeft: Float = 0
    public var jawOpen: Float = 0
    public var jawRight: Float = 0
    public var mouthClose: Float = 0
    public var mouthDimpleLeft: Float = 0
    public var mouthDimpleRight: Float = 0
    public var mouthFrownLeft: Float = 0
    public var mouthFrownRight: Float = 0
    public var mouthFunnel: Float = 0
    public var mouthLeft: Float = 0
    public var mouthLowerDownLeft: Float = 0
    public var mouthLowerDownRight: Float = 0
    public var mouthPressLeft: Float = 0
    public var mouthPressRight: Float = 0
    public var mouthPucker: Float = 0
    public var mouthRight: Float = 0
    public var mouthRollLower: Float = 0
    public var mouthRollUpper: Float = 0
    public var mouthShrugLower: Float = 0
    public var mouthShrugUpper: Float = 0
    public var mouthSmileLeft: Float = 0
    public var mouthSmileRight: Float = 0
    public var mouthStretchLeft: Float = 0
    public var mouthStretchRight: Float = 0
    public var mouthUpperUpLeft: Float = 0
    public var mouthUpperUpRight: Float = 0
    public var noseSneerLeft: Float = 0
    public var noseSneerRight: Float = 0
    public var tongueOut: Float = 0

    public init(lookAtPoint: SIMD2<Float> = .zero) {
        self.lookAtPoint = lookAtPoint
    }
}

public extension BlendShape {
    /// Linear interpolation of every channel and the gaze (`t` = 0 keeps `self`, 1 gives `next`)
    func lerp(next: Self, t: Float) -> Self {
        var mixed = self
        for keyPath in Self.wireOrder {
            mixed[keyPath: keyPath] += (next[keyPath: keyPath] - self[keyPath: keyPath]) * t
        }
        mixed.lookAtPoint += (next.lookAtPoint - lookAtPoint) * t
        return mixed
    }

    /// Alphabetical blend shape order shared by the perfect sync bridge
    /// array and the MotionV1 face packet. This list is the wire contract:
    /// encoder and decoder both derive their index mapping from it.
    static let wireOrder: [WritableKeyPath<BlendShape, Float> & Sendable] = [
        \.browDownLeft, \.browDownRight, \.browInnerUp,
        \.browOuterUpLeft, \.browOuterUpRight, \.cheekPuff,
        \.cheekSquintLeft, \.cheekSquintRight, \.eyeBlinkLeft,
        \.eyeBlinkRight, \.eyeLookDownLeft, \.eyeLookDownRight,
        \.eyeLookInLeft, \.eyeLookInRight, \.eyeLookOutLeft,
        \.eyeLookOutRight, \.eyeLookUpLeft, \.eyeLookUpRight,
        \.eyeSquintLeft, \.eyeSquintRight, \.eyeWideLeft,
        \.eyeWideRight, \.jawForward, \.jawLeft, \.jawOpen,
        \.jawRight, \.mouthClose, \.mouthDimpleLeft, \.mouthDimpleRight,
        \.mouthFrownLeft, \.mouthFrownRight, \.mouthFunnel, \.mouthLeft,
        \.mouthLowerDownLeft, \.mouthLowerDownRight, \.mouthPressLeft,
        \.mouthPressRight, \.mouthPucker, \.mouthRight, \.mouthRollLower,
        \.mouthRollUpper, \.mouthShrugLower, \.mouthShrugUpper, \.mouthSmileLeft,
        \.mouthSmileRight, \.mouthStretchLeft, \.mouthStretchRight, \.mouthUpperUpLeft,
        \.mouthUpperUpRight, \.noseSneerLeft, \.noseSneerRight, \.tongueOut,
    ]

    /// Entries of `wireOrder` that are zeroed while eye tracking is disabled:
    /// the contiguous eye block `eyeLookDownLeft ... eyeWideRight`. A test
    /// pins this range to the wire order.
    private static let eyeTrackingRange = 10..<22

    /// Pairs of sided shapes, as `wireOrder` key paths. Directional shapes such as
    /// `jawLeft` / `mouthRight` belong here too: mirroring moves the jaw the other way.
    /// The shapes missing from this list are the ones without a side, plus the gaze
    /// shapes of `gazeDirectionKeyPaths`.
    static let sidedPairs: [(WritableKeyPath<BlendShape, Float> & Sendable, WritableKeyPath<BlendShape, Float> & Sendable)] = [
        (\.browDownLeft, \.browDownRight),
        (\.browOuterUpLeft, \.browOuterUpRight),
        (\.cheekSquintLeft, \.cheekSquintRight),
        (\.eyeBlinkLeft, \.eyeBlinkRight),
        (\.eyeSquintLeft, \.eyeSquintRight),
        (\.eyeWideLeft, \.eyeWideRight),
        (\.jawLeft, \.jawRight),
        (\.mouthDimpleLeft, \.mouthDimpleRight),
        (\.mouthFrownLeft, \.mouthFrownRight),
        (\.mouthLeft, \.mouthRight),
        (\.mouthLowerDownLeft, \.mouthLowerDownRight),
        (\.mouthPressLeft, \.mouthPressRight),
        (\.mouthSmileLeft, \.mouthSmileRight),
        (\.mouthStretchLeft, \.mouthStretchRight),
        (\.mouthUpperUpLeft, \.mouthUpperUpRight),
        (\.noseSneerLeft, \.noseSneerRight),
    ]

    /// Gaze shapes, kept out of `sidedPairs` on purpose: they mirror as a direction
    /// through `gazeMirrored()` rather than by swapping the eyes.
    static let gazeDirectionKeyPaths: Set<WritableKeyPath<BlendShape, Float> & Sendable> = [
        \.eyeLookDownLeft, \.eyeLookDownRight,
        \.eyeLookInLeft, \.eyeLookInRight,
        \.eyeLookOutLeft, \.eyeLookOutRight,
        \.eyeLookUpLeft, \.eyeLookUpRight,
    ]

    /// Swaps every sided shape, turning values named after the subject's own left and
    /// right into the screen's left and right. The gaze channel is left untouched;
    /// see `gazeDirectionKeyPaths`.
    func mirrored() -> BlendShape {
        var mirrored = self
        for (left, right) in Self.sidedPairs {
            mirrored[keyPath: left] = self[keyPath: right]
            mirrored[keyPath: right] = self[keyPath: left]
        }
        return mirrored
    }

    /// Mirrors the gaze direction horizontally: each eye's nasal and temporal shapes
    /// swap and `lookAtPoint.x` flips with them, so the shape-driven eye meshes and the
    /// look at target keep agreeing. Keeping the values on their own eye (instead of
    /// swapping left and right) preserves per-eye asymmetry. The vertical axis has a
    /// single shared convention and stays untouched.
    func gazeMirrored() -> BlendShape {
        var mirrored = self
        mirrored.eyeLookInLeft = eyeLookOutLeft
        mirrored.eyeLookOutLeft = eyeLookInLeft
        mirrored.eyeLookInRight = eyeLookOutRight
        mirrored.eyeLookOutRight = eyeLookInRight
        mirrored.lookAtPoint.x = -lookAtPoint.x
        return mirrored
    }

    /// The complete horizontal parity flip. Self-inverse, so the same call converts
    /// observer-based wire data to anatomical sides and anatomical values to the
    /// mirrored presentation.
    func horizontallyMirrored() -> BlendShape {
        mirrored().gazeMirrored()
    }

    func appendWireOrderValues(to values: inout [Float], useEyeTracking: Bool) {
        values.reserveCapacity(values.count + Self.wireOrder.count)
        for (index, keyPath) in Self.wireOrder.enumerated() {
            let isGatedOff = !useEyeTracking && Self.eyeTrackingRange.contains(index)
            values.append(isGatedOff ? 0 : self[keyPath: keyPath])
        }
    }
}
