/// Uses Vision's subject-side naming: `leftEyeCenter` is the subject's physical left eye.
public struct HandPoseFaceContext: Sendable {
    /// Eye centers in the capture's normalized bottom-left-origin space.
    public let leftEyeCenter: SIMD2<Float>
    public let rightEyeCenter: SIMD2<Float>
    /// Head yaw in radians, or nil when it is unknown. It corrects the eye spacing, which
    /// shortens as the head turns away, so supply it only when the eye centers come from
    /// actual landmarks: an approximation from the face bounding box does not shorten the same way.
    public let headYaw: Float?

    public init(leftEyeCenter: SIMD2<Float>, rightEyeCenter: SIMD2<Float>, headYaw: Float? = nil) {
        self.leftEyeCenter = leftEyeCenter
        self.rightEyeCenter = rightEyeCenter
        self.headYaw = headYaw
    }
}
