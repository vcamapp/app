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
    private let analyzerState = ExpressionAnalyzerState()
    private let callbackState = CallbackState()

    public override init() {
        super.init()
    }

    public func setOnUpdate(_ handler: (@Sendable (FacialExpression) -> Void)?) {
        callbackState.setOnUpdate(handler)
    }

    public func configure(format: AVAudioFormat) {
        analyzerState.configure(format: format, observer: self)
    }

    public func reset() {
        analyzerState.reset()
    }

    /// Rate-limited to about 8 times a second
    public func analyze(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        analyzerState.analyzeIfNeeded(buffer: buffer, sampleTime: time.sampleTime)
    }
}

private final class CallbackState: Sendable {
    private let onUpdate = Mutex<(@Sendable (FacialExpression) -> Void)?>(nil)

    func setOnUpdate(_ handler: (@Sendable (FacialExpression) -> Void)?) {
        onUpdate.withLock { $0 = handler }
    }

    func notifyExpression(_ expression: FacialExpression) {
        onUpdate.withLock { $0 }?(expression)
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
