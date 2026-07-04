import Foundation
import SoundAnalysis
import Accelerate
import VCamEntity
import AVFAudio
import Synchronization

private final class AudioLevelCalculator: Sendable {
    private struct State: Sendable {
        var averagePowerForChannel0: Float = 0
    }

    private let levelLowPassTrig: Float32 = 0.30
    private let state = Mutex(State())

    func reset() {
        state.withLock {
            $0.averagePowerForChannel0 = 0
        }
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

        var value: Float = -100
        if avgValue != 0 {
            value = 20.0 * log10f(avgValue)
        }

        return state.withLock { state in
            state.averagePowerForChannel0 = (levelLowPassTrig * value) + ((1 - levelLowPassTrig) * state.averagePowerForChannel0)
            return Float(100 + state.averagePowerForChannel0) / 100.0
        }
    }
}

private final class ExpressionAnalyzerState: Sendable {
    private struct State: @unchecked Sendable {
        var analyzer: SNAudioStreamAnalyzer?
        var previousSampleTime = Date()
    }

    private let state = Mutex(State())
    private let inversedFps: Double = 1 / 8

    func configure(format: AVAudioFormat, observer: any SNResultsObserving) {
        state.withLock { state in
            state.analyzer = SNAudioStreamAnalyzer(format: format)
            do {
                let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
                request.windowDuration = CMTimeMakeWithSeconds(0.5, preferredTimescale: 48_000)
                request.overlapFactor = 0.9
                try state.analyzer?.add(request, withObserver: observer)
            } catch {
                // Silently fail if sound classification is unavailable
            }
        }
    }

    func reset() {
        state.withLock { state in
            state.analyzer = nil
            state.previousSampleTime = Date()
        }
    }

    /// Analyzes the buffer if enough time has passed since the last analysis.
    /// Returns true if analysis was performed.
    func analyzeIfNeeded(buffer: AVAudioPCMBuffer, sampleTime: AVAudioFramePosition) -> Bool {
        state.withLock { state in
            guard let analyzer = state.analyzer else { return false }
            guard Date().timeIntervalSince(state.previousSampleTime) >= inversedFps else { return false }

            analyzer.analyze(buffer, atAudioFramePosition: sampleTime)
            state.previousSampleTime = Date()
            return true
        }
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
