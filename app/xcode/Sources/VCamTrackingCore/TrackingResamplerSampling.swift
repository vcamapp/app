import Foundation
import Accelerate

/// The pure part of `TrackingResampler`: picks the output for a render time from the frames
/// it has. Kept free of state so a recorded stream can be re-run offline with exactly the
/// shipped math, and with alternative policies to compare fixes.
public enum TrackingResamplerSampling {
    public struct Frame: Sendable, Equatable {
        public var time: Double
        public var values: [Float]

        public init(time: Double, values: [Float]) {
            self.time = time
            self.values = values
        }
    }

    public struct Settings: Sendable, Equatable {
        public var maxPrediction: Double
        /// Upper bound for how many frame spans the output may run ahead of the last frame.
        /// nil reproduces the unbounded behavior
        public var maxExtrapolationFactor: Float?

        public init(maxPrediction: Double, maxExtrapolationFactor: Float? = nil) {
            self.maxPrediction = maxPrediction
            self.maxExtrapolationFactor = maxExtrapolationFactor
        }
    }

    public enum Mode: String, Codable, Sendable {
        /// Between two frames
        case interpolated
        /// Past the last frame, projected from the last two
        case extrapolated
        /// Past the last frame with nothing to project from, or before the first frame
        case held
    }

    public struct Output: Sendable, Equatable {
        public var values: [Float]
        public var mode: Mode
        public var factor: Float?
        public var spacing: Double?
    }

    public static func sample(at renderTime: Double, frames: [Frame], settings: Settings) -> Output? {
        guard !frames.isEmpty else { return nil }

        guard let prevIndex = frames.lastIndex(where: { $0.time <= renderTime }) else {
            return Output(values: frames[0].values, mode: .held, factor: nil, spacing: nil)
        }
        let prev = frames[prevIndex]
        if prevIndex + 1 < frames.count {
            let next = frames[prevIndex + 1]
            let span = next.time - prev.time
            guard span > 0 else { return Output(values: prev.values, mode: .held, factor: nil, spacing: span) }
            let t = Float((renderTime - prev.time) / span)
            let values = vDSP.linearInterpolate(prev.values, next.values, using: max(0, min(1, t)))
            return Output(values: values, mode: .interpolated, factor: nil, spacing: span)
        }
        return predict(from: prevIndex, frames: frames, renderTime: renderTime, settings: settings)
    }

    private static func predict(from index: Int, frames: [Frame], renderTime: Double, settings: Settings) -> Output {
        let last = frames[index]
        guard index > 0 else { return Output(values: last.values, mode: .held, factor: nil, spacing: nil) }
        let prev = frames[index - 1]
        let dt = last.time - prev.time
        guard dt > 0 else { return Output(values: last.values, mode: .held, factor: nil, spacing: dt) }
        let dtPred = min(renderTime - last.time, settings.maxPrediction)
        guard dtPred > 0 else { return Output(values: last.values, mode: .held, factor: 0, spacing: dt) }
        var factor = Float(dtPred / dt)
        if let limit = settings.maxExtrapolationFactor {
            factor = min(factor, limit)
        }
        let values = vDSP.linearInterpolate(prev.values, last.values, using: 1 + factor)
        return Output(values: values, mode: .extrapolated, factor: factor, spacing: dt)
    }
}
