import CoreMedia
import simd

/// The most recent face observation, for hand backends that relate hand
/// positions to the face. Uses Vision's subject-side naming: `leftEyeCenter`
/// is the subject's physical left eye.
public struct HandPoseFaceContext: Sendable {
    /// Eye centers in the capture's normalized bottom-left-origin space.
    public let leftEyeCenter: SIMD2<Float>
    public let rightEyeCenter: SIMD2<Float>

    public init(leftEyeCenter: SIMD2<Float>, rightEyeCenter: SIMD2<Float>) {
        self.leftEyeCenter = leftEyeCenter
        self.rightEyeCenter = rightEyeCenter
    }
}

/// An alternative backend for hand tracking on camera frames, injected by an
/// external module via `AvatarWebCamera.handPoseMapperFactory`.
///
/// Implementations receive raw camera frames and deliver their output through
/// their own channel. `face` carries the most recent face observation and is
/// nil until face landmarks have been processed (face tracking and emotion
/// detection both feed it). `fingersEnabled` mirrors the finger tracking
/// setting; when false the backend must keep tracking wrists but omit finger
/// data from its output. Instances are used from a single pipeline actor.
public protocol HandPoseMapper: AnyObject {
    func map(sampleBuffer: CMSampleBuffer, face: HandPoseFaceContext?, fingersEnabled: Bool)
}
