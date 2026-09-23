import simd
import VCamEntity
import VCamMotionV1

/// A face sample in the VCamMotion convention: the head pose is the subject's own
/// while the sided shapes and the gaze are named through the mirror, as ARKit reports them.
public struct VCamFaceMotion: Equatable, Sendable {
    public var head: VCamMotion.Head
    public var blendShape: BlendShape

    public init(head: VCamMotion.Head, blendShape: BlendShape) {
        self.head = head
        self.blendShape = blendShape
    }

    /// Mirroring the sided shapes and the gaze back yields the builders' anatomical input
    public var anatomicalBlendShape: BlendShape {
        blendShape.horizontallyMirrored()
    }

    public func vcamHeadTransform(useEyeTracking: Bool, useVowelEstimation: Bool, mirrored: Bool) -> [Float] {
        FaceTransformValues.vcamHeadTransform(
            translation: head.translation,
            rotationEuler: head.rotation.eulerAngles(),
            blendShape: anatomicalBlendShape,
            useEyeTracking: useEyeTracking,
            mirrored: mirrored,
            vowel: useVowelEstimation ? VowelEstimator.estimate(blendShape: blendShape) : .a
        )
    }

    public func perfectSync(useEyeTracking: Bool, mirrored: Bool) -> [Float] {
        FaceTransformValues.perfectSync(
            translation: head.translation,
            rotationEuler: head.rotation.eulerAngles(),
            blendShape: anatomicalBlendShape,
            useEyeTracking: useEyeTracking,
            mirrored: mirrored
        )
    }
}

public extension VCamMotion {
    var face: VCamFaceMotion {
        VCamFaceMotion(head: head, blendShape: blendShape)
    }
}
