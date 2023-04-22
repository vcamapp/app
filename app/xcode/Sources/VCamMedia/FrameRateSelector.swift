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
        var minFrameDuration: CMTime?
        var maxFrameDuration: CMTime?

        if ranges.contains(where: { $0.minFrameRate <= fps && fps <= $0.maxFrameRate }) {
            minFrameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
        }

        if let maxFPS = ranges.max(by: { $0.maxFrameRate < $1.maxFrameRate })?.maxFrameRate {
            let minFPS = ranges.min(by: { $0.minFrameRate < $1.minFrameRate })?.minFrameRate ?? fps
            maxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(min(max(minFPS, fps), maxFPS)))
        }

        return (minFrameDuration, maxFrameDuration)
    }
}

public protocol AVFrameRateRangeProtocol {
    var minFrameRate: Float64 { get }
    var maxFrameRate: Float64 { get }
}

extension AVFrameRateRange: AVFrameRateRangeProtocol {}
