import CoreMedia
import AVFoundation

public enum FrameRateSelector {
    public static func supportsFrameRate(_ fps: Float64, ranges: [some AVFrameRateRangeProtocol]) -> Bool {
        ranges.contains { $0.minFrameRate <= fps && fps <= $0.maxFrameRate }
    }

    /// The frame rate that actually results from the durations returned by `recommendedFrameRate`
    public static func effectiveFrameRate(of frameDuration: CMTime) -> Int? {
        guard frameDuration.isValid, frameDuration.seconds > 0 else { return nil }
        return Int((1 / frameDuration.seconds).rounded())
    }

    public static func recommendedFrameRate(targetFPS fps: Float64, supportedFrameRateRanges ranges: [some AVFrameRateRangeProtocol]) -> (minFrameDuration: CMTime, maxFrameDuration: CMTime) {
        if ranges.isEmpty {
            return (.invalid, .invalid)
        }

        guard let candidateRange = ranges.first(where: { $0.minFrameRate <= fps && fps <= $0.maxFrameRate }) else {
            if let range = ranges.filter({ $0.maxFrameRate <= fps }).max(by: { $0.maxFrameRate < $1.maxFrameRate }) {
                return (range.minFrameDuration, range.minFrameDuration)
            }
            let range = ranges.min { $0.maxFrameRate < $1.maxFrameRate }
            return (range?.maxFrameDuration ?? .invalid, range?.maxFrameDuration ?? .invalid)
        }

        let timescale = min(CMTimeScale(Float64(candidateRange.minFrameDuration.value) * fps), candidateRange.minFrameDuration.timescale)
        return (.init(value: candidateRange.minFrameDuration.value, timescale: timescale), .init(value: candidateRange.minFrameDuration.value, timescale: timescale))
    }
}

public protocol AVFrameRateRangeProtocol {
    var minFrameRate: Float64 { get }
    var maxFrameRate: Float64 { get }
    var minFrameDuration: CMTime { get }
    var maxFrameDuration: CMTime { get }
}

extension AVFrameRateRange: AVFrameRateRangeProtocol {}
