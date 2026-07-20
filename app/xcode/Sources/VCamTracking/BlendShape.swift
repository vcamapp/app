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
}

public extension BlendShape {
    /// Alphabetical ARKit blend shape order shared by the perfect sync bridge
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

    func appendWireOrderValues(to values: inout [Float], useEyeTracking: Bool) {
        values.reserveCapacity(values.count + Self.wireOrder.count)
        for (index, keyPath) in Self.wireOrder.enumerated() {
            let isGatedOff = !useEyeTracking && Self.eyeTrackingRange.contains(index)
            values.append(isGatedOff ? 0 : self[keyPath: keyPath])
        }
    }
}
