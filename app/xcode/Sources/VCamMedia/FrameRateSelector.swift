//
//  FrameRateSelector.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/22.
//

import CoreMedia
import AVFoundation

public enum FrameRateSelector {
    public static func recommendedFrameRate(targetFPS fps: Float64, supportedFrameRateRanges ranges: [some AVFrameRateRangeProtocol]) -> (minFrameDuration: CMTime?, maxFrameDuration: CMTime?) {
        guard let range = ranges.first(where: { fps < $0.maxFrameRate }) else {
            return (ranges.first?.maxFrameDuration, nil)
        }

        var minFrameDuration: CMTime?
        var maxFrameDuration: CMTime?

        if range.minFrameRate <= fps && fps <= range.maxFrameRate {
            lazy var estimatedMinDuration = CMTime(value: range.minFrameDuration.value, timescale: CMTimeScale(fps) * CMTimeScale(range.minFrameDuration.value))
            minFrameDuration = fps <= range.maxFrameRate ? estimatedMinDuration : range.maxFrameDuration
        }

        lazy var estimatedMaxDuration = CMTime(value: range.maxFrameDuration.value, timescale: CMTimeScale(fps) * CMTimeScale(range.maxFrameDuration.value))
        maxFrameDuration = range.minFrameRate <= fps ? estimatedMaxDuration : range.minFrameDuration

        return (minFrameDuration, maxFrameDuration)
    }
}

public protocol AVFrameRateRangeProtocol {
    var minFrameRate: Float64 { get }
    var maxFrameRate: Float64 { get }
    var minFrameDuration: CMTime { get }
    var maxFrameDuration: CMTime { get }
}

extension AVFrameRateRange: AVFrameRateRangeProtocol {}
