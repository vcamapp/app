public struct RenderingFeature: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Screen effects (color grading, bloom, vignette, lens flare)
    public static let postEffect = RenderingFeature(rawValue: 1 << 0)
    public static let shadow = RenderingFeature(rawValue: 1 << 1)
    public static let qualityLevel = RenderingFeature(rawValue: 1 << 2)
    public static let vSync = RenderingFeature(rawValue: 1 << 3)
    /// Merging the meshes of a model while loading it
    public static let meshOptimization = RenderingFeature(rawValue: 1 << 4)
    /// Driving the whole body from an external motion capture device
    public static let fullBodyTracking = RenderingFeature(rawValue: 1 << 5)
    public static let urp = RenderingFeature(rawValue: 1 << 6)
    /// Driving the avatar from a performer over the VMC Protocol
    public static let vmcProtocol = RenderingFeature(rawValue: 1 << 7)
    /// Shaping the mouth from the vowels heard in the microphone
    public static let micVowelEstimation = RenderingFeature(rawValue: 1 << 8)
    /// Moving the mouth with the microphone while Perfect Sync tracking moves the rest of the face
    public static let micLipSyncWithPerfectSync = RenderingFeature(rawValue: 1 << 9)
    /// The VCam API that other apps on this Mac control the app through
    public static let externalControl = RenderingFeature(rawValue: 1 << 10)
    /// The avatar lighting each scene keeps
    public static let sceneLighting = RenderingFeature(rawValue: 1 << 11)
    /// Receiving every bone and the expressions over the VMC Protocol, rather than only the head and torso
    public static let vmcProtocolFullPose = RenderingFeature(rawValue: 1 << 12)

    /// The features of the engine
    public static let engine: RenderingFeature = [
        .postEffect, .shadow, .qualityLevel, .vSync, .meshOptimization, .fullBodyTracking, .urp
    ]

    /// The features the running renderer implements. Must be set before the UI is built.
    @MainActor public static var supported = RenderingFeature.engine
}
