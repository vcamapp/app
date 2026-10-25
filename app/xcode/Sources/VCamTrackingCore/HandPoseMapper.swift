#if canImport(CoreMedia)
import CoreMedia

/// Injected via `AvatarWebCamera.handPoseMapperFactory`. Implementations deliver their output
/// through their own channel. `face` is nil until face landmarks have been processed. When
/// `fingersEnabled` is false the backend must keep tracking wrists but omit finger data.
/// Instances are used from a single pipeline actor.
public protocol HandPoseMapper: AnyObject {
    func map(sampleBuffer: CMSampleBuffer, face: HandPoseFaceContext?, fingersEnabled: Bool)
}
#endif
