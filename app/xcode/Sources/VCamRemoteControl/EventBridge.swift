import Foundation
import Observation
import VCamControl
import VCamData

/// Feeds VCam state changes into the EventPublisher while the server runs.
/// Motion, expression and subtitle changes are observed on UniState, which
/// reflects them regardless of the source (the UI, shortcuts, or the API);
/// avatar loads hook into AvatarControl because there is no completion signal.
@MainActor
final class EventBridge {
    private let uniState: UniState
    private let eventPublisher: EventPublisher
    private var isActive = false

    init(uniState: UniState = .shared, eventPublisher: EventPublisher = .shared) {
        self.uniState = uniState
        self.eventPublisher = eventPublisher
    }

    func start() {
        guard !isActive else { return }
        isActive = true
        AvatarControl.onLoad = { [weak self] avatarId in
            self?.publish(.avatarLoaded(avatarId: avatarId))
        }
        observeMotionPlaying(previous: uniState.isMotionPlaying)
        observeExpression(previous: currentExpressionName)
        observeScene(previous: SceneControl.provider?.activeScene?.id)
        observeSubtitle(previous: uniState.subtitle)
    }

    func stop() {
        isActive = false
        AvatarControl.onLoad = nil
    }

    private func publish(_ notification: VCamNotification) {
        Task { @MainActor in
            await eventPublisher.publish(notification)
        }
    }

    private var currentExpressionName: String? {
        guard let index = uniState.currentExpressionIndex,
              uniState.expressions.indices.contains(index) else { return nil }
        return uniState.expressions[index].name
    }

    /// Re-arms observation after each change; the loop ends when `isActive` turns false
    private func observeMotionPlaying(previous: [String: Bool]) {
        guard isActive else { return }
        withObservationTracking {
            _ = uniState.isMotionPlaying
        } onChange: {
            Task { @MainActor [weak self] in
                guard let self, self.isActive else { return }
                let current = self.uniState.isMotionPlaying
                for (motionId, isPlaying) in current where isPlaying && previous[motionId] != true {
                    self.publish(.motionStarted(motionId: motionId))
                }
                for (motionId, isPlaying) in previous where isPlaying && current[motionId] != true {
                    self.publish(.motionStopped(motionId: motionId))
                }
                self.observeMotionPlaying(previous: current)
            }
        }
    }

    private func observeExpression(previous: String?) {
        guard isActive else { return }
        withObservationTracking {
            _ = uniState.currentExpressionIndex
            _ = uniState.expressions
        } onChange: {
            Task { @MainActor [weak self] in
                guard let self, self.isActive else { return }
                let current = self.currentExpressionName
                if let current, current != previous {
                    self.publish(.expressionChanged(name: current))
                }
                self.observeExpression(previous: current)
            }
        }
    }

    private func observeSubtitle(previous: String) {
        guard isActive else { return }
        withObservationTracking {
            _ = uniState.subtitle
        } onChange: {
            Task { @MainActor [weak self] in
                guard let self, self.isActive else { return }
                let current = self.uniState.subtitle
                if current != previous {
                    self.publish(.subtitleChanged(text: current))
                }
                self.observeSubtitle(previous: current)
            }
        }
    }

    private func observeScene(previous: Int32?) {
        guard isActive else { return }
        withObservationTracking {
            _ = SceneControl.provider?.activeScene?.id
        } onChange: {
            Task { @MainActor [weak self] in
                guard let self, self.isActive else { return }
                let current = SceneControl.provider?.activeScene?.id
                if let current, current != previous {
                    self.publish(.sceneLoaded(sceneId: Int(current)))
                }
                self.observeScene(previous: current)
            }
        }
    }
}
