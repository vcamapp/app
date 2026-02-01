import Foundation
import SoundAnalysis
import Accelerate
import VCamEntity
import AVFAudio
import os

private final class AudioLevelCalculator: @unchecked Sendable {
    private var averagePowerForChannel0: Float = 0
    private let levelLowPassTrig: Float32 = 0.30
    private var lock = os_unfair_lock()

    func reset() {
        os_unfair_lock_lock(&lock)
        averagePowerForChannel0 = 0
        os_unfair_lock_unlock(&lock)
    }

    func computeAudioLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard buffer.format.channelCount > 0,
              let channelData = buffer.floatChannelData else {
            return 0
        }

        let samples = channelData[0]
        let frameCount = vDSP_Length(buffer.frameLength)

        var avgValue: Float = 0
        vDSP_meamgv(samples, 1, &avgValue, frameCount)

        var v: Float = -100
        if avgValue != 0 {
            v = 20.0 * log10f(avgValue)
        }

        os_unfair_lock_lock(&lock)
        averagePowerForChannel0 = (levelLowPassTrig * v) + ((1 - levelLowPassTrig) * averagePowerForChannel0)
        let result = Float(100 + averagePowerForChannel0) / 100.0
        os_unfair_lock_unlock(&lock)

        return result
    }
}

private final class ExpressionAnalyzerState: @unchecked Sendable {
    private var analyzer: SNAudioStreamAnalyzer?
    private var previousSampleTime = Date()
    private var lock = os_unfair_lock()

    private let inversedFps: Double = 1 / 8

    func configure(format: AVAudioFormat, observer: any SNResultsObserving) {
        os_unfair_lock_lock(&lock)
        analyzer = SNAudioStreamAnalyzer(format: format)
        do {
            let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
            request.windowDuration = CMTimeMakeWithSeconds(0.5, preferredTimescale: 48_000)
            request.overlapFactor = 0.9
            try analyzer?.add(request, withObserver: observer)
        } catch {
            // Silently fail if sound classification is unavailable
        }
        os_unfair_lock_unlock(&lock)
    }

    func reset() {
        os_unfair_lock_lock(&lock)
        analyzer = nil
        previousSampleTime = Date()
        os_unfair_lock_unlock(&lock)
    }

    /// Analyzes the buffer if enough time has passed since the last analysis.
    /// Returns true if analysis was performed.
    func analyzeIfNeeded(buffer: AVAudioPCMBuffer, sampleTime: AVAudioFramePosition) -> Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }

        guard let analyzer else { return false }
        guard Date().timeIntervalSince(previousSampleTime) >= inversedFps else { return false }

        analyzer.analyze(buffer, atAudioFramePosition: sampleTime)
        previousSampleTime = Date()
        return true
    }
}

public final class AudioExpressionEstimator: NSObject, Sendable {
    private let audioLevelCalculator = AudioLevelCalculator()
    private let analyzerState = ExpressionAnalyzerState()
    private let callbackState = CallbackState()

    public override init() {
        super.init()
    }

    public func setOnUpdate(_ handler: (@Sendable (FacialExpression) -> Void)?) {
        Task { await callbackState.setOnUpdate(handler) }
    }

    public func setOnAudioLevelUpdate(_ handler: (@Sendable (Float) -> Void)?) {
        Task { await callbackState.setOnAudioLevelUpdate(handler) }
    }

    public func configure(format: AVAudioFormat) {
        audioLevelCalculator.reset()
        analyzerState.configure(format: format, observer: self)
    }

    public func reset() {
        audioLevelCalculator.reset()
        analyzerState.reset()
        Task { await callbackState.reset() }
    }

    /// Analyzes the audio buffer for expression estimation and audio level.
    /// Audio level computation and expression analysis are done synchronously for performance.
    public func analyze(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        // Compute audio level synchronously (high frequency, needs to be fast)
        let level = audioLevelCalculator.computeAudioLevel(from: buffer)

        // Notify audio level update asynchronously
        Task { await callbackState.notifyAudioLevel(level) }

        // Expression analysis is rate-limited (~8fps) and runs synchronously
        _ = analyzerState.analyzeIfNeeded(buffer: buffer, sampleTime: time.sampleTime)
    }
}

/// Actor for managing callbacks safely.
private actor CallbackState {
    var onUpdate: (@Sendable (FacialExpression) -> Void)?
    var onAudioLevelUpdate: (@Sendable (Float) -> Void)?

    func setOnUpdate(_ handler: (@Sendable (FacialExpression) -> Void)?) {
        onUpdate = handler
    }

    func setOnAudioLevelUpdate(_ handler: (@Sendable (Float) -> Void)?) {
        onAudioLevelUpdate = handler
    }

    func reset() {
        onUpdate = nil
        onAudioLevelUpdate = nil
    }

    func notifyExpression(_ expression: FacialExpression) {
        onUpdate?(expression)
    }

    func notifyAudioLevel(_ level: Float) {
        onAudioLevelUpdate?(level)
    }
}

extension AudioExpressionEstimator: SNResultsObserving {
    public func request(_ request: any SNRequest, didProduce result: any SNResult) {
        guard let result = result as? SNClassificationResult,
              let classification = result.classification(forIdentifier: "laughter") else {
            Task { await callbackState.notifyExpression(.neutral) }
            return
        }

        let expression: FacialExpression = classification.confidence > 0.5 ? .laugh : .neutral
        Task { await callbackState.notifyExpression(expression) }
    }
}
