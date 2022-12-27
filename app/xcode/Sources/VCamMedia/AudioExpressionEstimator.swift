//
//  AudioExpressionEstimator.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/07/31.
//

import SoundAnalysis
import Accelerate
import VCamEntity

public final class AudioExpressionEstimator: NSObject {
    public var onUpdate: ((FacialExpression) -> Void)?
    public var onAudioLevelUpdate: ((Float) -> Void)?

    private var analyzer: SNAudioStreamAnalyzer?
    private var averagePowerForChannel0: Float = 0
    private var previousSampleTime = Date()

    private let levelLowPassTrig: Float32 = 0.30
    private let inversedFps: Double = 1 / 8
    private let queue = DispatchQueue(label: "com.github.tattn.vcam.queue.audio-expression")

    public func configure(format: AVAudioFormat) {
        averagePowerForChannel0 = 0
        analyzer = SNAudioStreamAnalyzer(format: format)

        do {
            let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
            request.windowDuration = CMTimeMakeWithSeconds(0.5, preferredTimescale: 48_000)
            request.overlapFactor = 0.9

            try analyzer!.add(request, withObserver: self)
        } catch {
        }
    }

    public func reset() {
        onUpdate = nil
        onAudioLevelUpdate = nil
        analyzer = nil
    }

    public func analyze(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        queue.async { [self] in
            if onUpdate != nil {
                if Date().timeIntervalSince(previousSampleTime) >= inversedFps {
                    analyzer?.analyze(buffer, atAudioFramePosition: time.sampleTime)
                    previousSampleTime = Date()
                }
            }

            onAudioLevelUpdate?(audioLevel(of: buffer))
        }
    }

    private func audioLevel(of buffer: AVAudioPCMBuffer) -> Float {
        guard buffer.format.channelCount > 0 else {
            return 0
        }
        let samples = buffer.floatChannelData![0]
        let inNumberFrames = vDSP_Length(buffer.frameLength)

        var avgValue: Float = 0
        vDSP_meamgv(samples, 1, &avgValue, inNumberFrames)

        var v: Float = -100
        if avgValue != 0 {
            v = 20.0 * log10f(avgValue)
        }

        averagePowerForChannel0 = (levelLowPassTrig * v) + ((1 - levelLowPassTrig) * averagePowerForChannel0)
        return Float(100 + averagePowerForChannel0) / 100.0 // 0 to 1
    }
}

extension AudioExpressionEstimator: SNResultsObserving {
    public func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult,
              let classification = result.classification(forIdentifier: "laughter") else {
            onUpdate?(.neutral)
            return
        }

        onUpdate?(classification.confidence > 0.5 ? .laugh : .neutral)
    }
}
