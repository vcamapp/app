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

    public static let all: RenderingFeature = [
        .postEffect, .shadow, .qualityLevel, .vSync, .meshOptimization, .fullBodyTracking, .urp
    ]

    /// The features the running engine implements. Must be set before the UI is built.
    @MainActor public static var supported = RenderingFeature.all
}
