//
//  FrameRateSelector.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/22.
//

import CoreMedia
import AVFoundation

public enum FrameRateSelector {
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
