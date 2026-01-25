//
//  TrackingSmoothing.swift
//
//
//  Created by Tatsuya Tanaka on 2026/01/24.
//

public struct TrackingSmoothing: Sendable {
    /// Normalized value in 0.0...1.0.
    let value: Double

    init(value: Double) {
        self.value = value
    }

    var isEnabled: Bool {
        value > 0.0001
    }

    func settings(fps: Double = 60) -> TrackingResampler.Settings {
        assert(fps > 0, "TrackingResampler.Settings.fps must be > 0")
        let t = value
        let eased = t * t // Ease-in for finer control in low range.
        let bufferDelay = eased * 0.12 // 0ms - 120ms
        let maxPrediction = eased * 0.18 // 0ms - 180ms
        return TrackingResampler.Settings(
            fps: fps,
            bufferDelay: bufferDelay,
            maxPrediction: maxPrediction,
            maxFrames: 10
        )
    }
}
