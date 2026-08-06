import simd

@available(iOS 26.0, macOS 26.0, *)
public struct HandPoseV1: Sendable {
    public static let missing = HandPoseV1()

    public var state: HandTrackingStateV1
    public var wristPosition: SIMD3<Float>
    /// World/subject-space rotation delta from the canonical front-facing
    /// palm. Screen-plane directions are already aligned with the displayed
    /// camera preview. A mirrored opposite-hand presentation may reverse the
    /// longitudinal twist, but must not reflect quaternion components wholesale.
    public var wristRotation: simd_quatf
    public var normalizedJoints: InlineArray<21, SIMD3<Float>>

    public init(state: HandTrackingStateV1 = .missing, wristPosition: SIMD3<Float> = .zero,
                wristRotation: simd_quatf = .init(ix: 0, iy: 0, iz: 0, r: 1),
                normalizedJoints: InlineArray<21, SIMD3<Float>> = InlineArray<21, SIMD3<Float>>(repeating: .zero)) {
        self.state = state
        self.wristPosition = wristPosition
        self.wristRotation = wristRotation
        self.normalizedJoints = normalizedJoints
    }
}
