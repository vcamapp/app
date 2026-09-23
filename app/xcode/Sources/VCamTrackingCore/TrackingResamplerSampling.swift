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
        /// Channels that are weights in 0...1. Interpolating between frames keeps them there,
        /// projecting past the last frame does not: a blink still closing when a silence starts
        /// would otherwise run past fully closed
        public var unitIntervalChannels: Range<Int>?

        public init(maxPrediction: Double, maxExtrapolationFactor: Float? = nil, unitIntervalChannels: Range<Int>? = nil) {
            self.maxPrediction = maxPrediction
            self.maxExtrapolationFactor = maxExtrapolationFactor
            self.unitIntervalChannels = unitIntervalChannels
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
        /// The render time ran past the newest frame by more than the sender's jitter explains,
        /// so the frames stopped coming and the output is a guess until they are back
        public var isInSilence = false
    }

    /// How many typical frame spans past the newest frame count as a silence. Wider than the
    /// receive jitter (p99 about 1.2 spans over USB) so that steady streams never trip it
    public static let silenceSpans = 2.5

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
        let span = max(dt, typicalSpacing(of: frames[...index]))
        let overrun = renderTime - last.time
        let isInSilence = span > 0 && overrun > span * silenceSpans
        guard dt > 0 else { return Output(values: last.values, mode: .held, factor: nil, spacing: dt, isInSilence: isInSilence) }
        let dtPred = min(overrun, settings.maxPrediction)
        guard dtPred > 0 else { return Output(values: last.values, mode: .held, factor: 0, spacing: dt, isInSilence: isInSilence) }
        var factor = Float(dtPred / span)
        if let limit = settings.maxExtrapolationFactor {
            factor = min(factor, limit)
        }
        var values = vDSP.linearInterpolate(prev.values, last.values, using: 1 + factor)
        if let channels = settings.unitIntervalChannels?.clamped(to: values.indices) {
            for channel in channels {
                values[channel] = min(max(values[channel], 0), 1)
            }
        }
        return Output(values: values, mode: .extrapolated, factor: factor, spacing: dt, isInSilence: isInSilence)
    }

    /// Packets arrive in bunches when the main thread stalls or Wi-Fi batches them, so the last
    /// two frames can sit well under a millisecond apart while their values are a full frame
    /// apart. Dividing by that spacing turns one frame of motion into hundreds. The mean
    /// spacing of the buffer is what the pair would have had if it had arrived evenly, and a
    /// silence inside the buffer only raises it, which errs toward holding
    private static func typicalSpacing(of frames: ArraySlice<Frame>) -> Double {
        guard frames.count >= 3, let first = frames.first, let last = frames.last else { return 0 }
        return (last.time - first.time) / Double(frames.count - 1)
    }
}

/// Eases the output back onto the frames after a silence. While the frames stop the output is
/// projected or held, and the first frames back put the sampled value somewhere else: a head
/// turned on during a 200ms Wi-Fi drop otherwise lands 10-15° away in one frame
public struct TrackingResamplerRecovery: Sendable {
    public static let duration: Double = 0.1

    private var last: [Float]?
    private var wasInSilence = false
    private var blend: (from: [Float], start: Double)?

    public init() {}

    public mutating func apply(_ output: TrackingResamplerSampling.Output, at renderTime: Double) -> [Float] {
        if output.isInSilence {
            wasInSilence = true
            blend = nil
            last = output.values
            return output.values
        }
        if wasInSilence, let last, last.count == output.values.count {
            blend = (last, renderTime)
        }
        wasInSilence = false
        var values = output.values
        if let blend {
            let progress = (renderTime - blend.start) / Self.duration
            if progress >= 1 {
                self.blend = nil
            } else {
                let eased = Float(progress * progress * (3 - 2 * progress))
                values = vDSP.linearInterpolate(blend.from, values, using: max(0, eased))
            }
        }
        last = values
        return values
    }
}
