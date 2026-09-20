public struct TrackingSmoothing: Sendable {
    /// Normalized value in 0.0...1.0.
    public let value: Double

    public init(value: Double) {
        self.value = value
    }

    public var isEnabled: Bool {
        value > 0.0001
    }

    /// Ease-in for finer control in the low range
    private var eased: Double { value * value }

    /// How far behind the newest frame the output runs, so a late frame still has a
    /// neighbor to interpolate to. 0ms - 120ms
    public var bufferDelay: Double { eased * 0.12 }

    /// How far past the last frame the output keeps moving during a silence. 0ms - 180ms
    public var maxPrediction: Double { eased * 0.18 }

    /// Frames kept for sampling
    public static let maxFrames = 10

    package func settings(fps: Double = 60) -> TrackingResampler.Settings {
        assert(fps > 0, "TrackingResampler.Settings.fps must be > 0")
        return TrackingResampler.Settings(
            fps: fps,
            bufferDelay: bufferDelay,
            maxPrediction: maxPrediction,
            maxFrames: Self.maxFrames
        )
    }
}
