import Foundation
import SoundAnalysis
import VCamEntity
import AVFAudio
import Synchronization

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

    func analyzeIfNeeded(buffer: AVAudioPCMBuffer, sampleTime: AVAudioFramePosition) {
        state.withLock { state in
            guard let analyzer = state.analyzer else { return }
            guard Date().timeIntervalSince(state.previousSampleTime) >= inversedFps else { return }

            analyzer.analyze(buffer, atAudioFramePosition: sampleTime)
            state.previousSampleTime = Date()
        }
    }
}

public final class AudioExpressionEstimator: NSObject, Sendable {
    private let audioLevelMeter = AudioLevelMeter()
    private let analyzerState = ExpressionAnalyzerState()
    private let callbackState = CallbackState()

    public override init() {
        super.init()
    }

    public func setOnUpdate(_ handler: (@Sendable (FacialExpression) -> Void)?) {
        callbackState.setOnUpdate(handler)
    }

    public func setOnAudioLevelUpdate(_ handler: (@Sendable (Float) -> Void)?) {
        callbackState.setOnAudioLevelUpdate(handler)
    }

    public func configure(format: AVAudioFormat) {
        audioLevelMeter.reset()
        analyzerState.configure(format: format, observer: self)
    }

    public func reset() {
        audioLevelMeter.reset()
        analyzerState.reset()
        callbackState.reset()
    }

    /// Runs synchronously on the caller's thread, callbacks included
    public func analyze(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        let level = audioLevelMeter.level(of: buffer)

        callbackState.notifyAudioLevel(level)

        // Expression analysis is rate-limited (~8fps)
        analyzerState.analyzeIfNeeded(buffer: buffer, sampleTime: time.sampleTime)
    }
}

private final class CallbackState: Sendable {
    private struct State: Sendable {
        var onUpdate: (@Sendable (FacialExpression) -> Void)?
        var onAudioLevelUpdate: (@Sendable (Float) -> Void)?
    }

    private let state = Mutex(State())

    func setOnUpdate(_ handler: (@Sendable (FacialExpression) -> Void)?) {
        state.withLock { $0.onUpdate = handler }
    }

    func setOnAudioLevelUpdate(_ handler: (@Sendable (Float) -> Void)?) {
        state.withLock { $0.onAudioLevelUpdate = handler }
    }

    func reset() {
        state.withLock {
            $0.onUpdate = nil
            $0.onAudioLevelUpdate = nil
        }
    }

    func notifyExpression(_ expression: FacialExpression) {
        state.withLock { $0.onUpdate }?(expression)
    }

    func notifyAudioLevel(_ level: Float) {
        state.withLock { $0.onAudioLevelUpdate }?(level)
    }
}

extension AudioExpressionEstimator: SNResultsObserving {
    public func request(_ request: any SNRequest, didProduce result: any SNResult) {
        guard let result = result as? SNClassificationResult,
              let classification = result.classification(forIdentifier: "laughter") else {
            callbackState.notifyExpression(.neutral)
            return
        }

        let expression: FacialExpression = classification.confidence > 0.5 ? .laugh : .neutral
        callbackState.notifyExpression(expression)
    }
}
