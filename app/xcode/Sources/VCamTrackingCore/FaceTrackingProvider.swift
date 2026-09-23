import CoreMedia
import simd
import VCamMotionV1

/// The head transform uses the same convention as a VCamMotion packet (translation in the
/// avatar's unit space, rotation as euler radians), and `blendShape` carries the full 52
/// coefficients plus gaze.
public struct CameraFaceTrackingResult: Sendable {
    public var headTranslation: SIMD3<Float>
    public var headRotationEuler: SIMD3<Float>
    public var blendShape: BlendShape
    /// Eye centers for hand backends that anchor to the face, when the backend
    /// can supply them. nil keeps the previous frame's anchor.
    public var faceContext: HandPoseFaceContext?

    public init(
        headTranslation: SIMD3<Float>,
        headRotationEuler: SIMD3<Float>,
        blendShape: BlendShape,
        faceContext: HandPoseFaceContext? = nil
    ) {
        self.headTranslation = headTranslation
        self.headRotationEuler = headRotationEuler
        self.blendShape = blendShape
        self.faceContext = faceContext
    }
}

/// Injected via `AvatarWebCamera.faceTrackingProviderFactory`. `process` returns nil when
/// no face is present in the frame. Instances are used from a single pipeline actor.
public protocol FaceTrackingProvider: AnyObject {
    func process(sampleBuffer: CMSampleBuffer, captureSize: CGSize) -> CameraFaceTrackingResult?
    func calibrate()
}
