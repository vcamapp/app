import Foundation
import Observation
import VCamControl
import VCamData
import VCamEntity
import VCamTrackingCore

/// Feeds VCam state changes into the EventPublisher while the server runs.
/// Motion, expression and subtitle changes are observed on UniState, and object
/// changes on the scene's objects, which reflect them regardless of the source
/// (the UI, shortcuts, or the API);
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
        observeExpression(previous: uniState.currentExpressions)
        observeScene(previous: SceneControl.provider?.activeScene?.id)
        observeSubtitle(previous: uniState.subtitle)
        observeTracking(previous: trackingStatuses)
        observeObjects(previous: objects)
        observeShortcuts(previous: shortcuts)
        observeRunningShortcuts(previous: ShortcutControl.provider?.runningShortcutIDs ?? [])
        observeRecording(previous: RecordingControl.provider?.state)
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

    /// Re-arms observation after each change; the loop ends when `isActive` turns false
    private func observeMotionPlaying(previous: [String: Bool]) {
        guard isActive else { return }
        withObservationTracking {
            _ = uniState.isMotionPlaying
        } onChange: { [weak self] in
            Task { @MainActor in
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

    private func observeExpression(previous: [AppliedExpression]) {
        guard isActive else { return }
        withObservationTracking {
            _ = uniState.currentExpressions
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, self.isActive else { return }
                let current = self.uniState.currentExpressions
                if current != previous {
                    self.publish(.expressionChanged(expressions: current.map { ExpressionWeight(name: $0.name, weight: $0.weight) }))
                }
                self.observeExpression(previous: current)
            }
        }
    }

    private func observeSubtitle(previous: String) {
        guard isActive else { return }
        withObservationTracking {
            _ = uniState.subtitle
        } onChange: { [weak self] in
            Task { @MainActor in
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
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, self.isActive else { return }
                let current = SceneControl.provider?.activeScene?.id
                if let current, current != previous {
                    self.publish(.sceneLoaded(sceneId: Int(current)))
                }
                self.observeScene(previous: current)
            }
        }
    }

    private var objects: [SceneObjectControl.Object] {
        SceneObjectControl.provider?.objects ?? []
    }

    private func observeObjects(previous: [SceneObjectControl.Object]) {
        guard isActive else { return }
        withObservationTracking {
            _ = objects
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, self.isActive else { return }
                let current = self.objects
                let previousById = Dictionary(uniqueKeysWithValues: previous.map { ($0.id, $0) })
                let currentIds = Set(current.map(\.id))
                let added = current.filter { previousById[$0.id] == nil }.map { Int($0.id) }
                let changed = current.filter { object in previousById[object.id].map { $0 != object } ?? false }.map { Int($0.id) }
                let removed = previous.filter { !currentIds.contains($0.id) }.map { Int($0.id) }
                if !added.isEmpty || !changed.isEmpty || !removed.isEmpty {
                    self.publish(.objectsChanged(added: added, changed: changed, removed: removed))
                }
                self.observeObjects(previous: current)
            }
        }
    }

    private var trackingStatuses: [String: ConnectionStatus] {
        Dictionary(uniqueKeysWithValues: TrackingControl.provider?.sources.map { ($0.id, $0.status) } ?? [])
    }

    private func observeTracking(previous: [String: ConnectionStatus]) {
        guard isActive else { return }
        withObservationTracking {
            _ = trackingStatuses
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, self.isActive else { return }
                let current = self.trackingStatuses
                for (sourceId, status) in current where status == .connected && previous[sourceId] != .connected {
                    self.publish(.trackingConnected(sourceId: sourceId))
                }
                for (sourceId, status) in previous where status == .connected && current[sourceId] != .connected {
                    self.publish(.trackingDisconnected(sourceId: sourceId))
                }
                self.observeTracking(previous: current)
            }
        }
    }

    /// Only what the API shows, so that editing the actions of a shortcut sends nothing
    private var shortcuts: [Shortcut] {
        ShortcutControl.provider?.shortcuts.map(Shortcut.init) ?? []
    }

    private func observeShortcuts(previous: [Shortcut]) {
        guard isActive else { return }
        withObservationTracking {
            _ = shortcuts
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, self.isActive else { return }
                let current = self.shortcuts
                if current != previous {
                    self.publish(.shortcutsChanged(shortcuts: current))
                }
                self.observeShortcuts(previous: current)
            }
        }
    }

    private func observeRunningShortcuts(previous: Set<UUID>) {
        guard isActive else { return }
        withObservationTracking {
            _ = ShortcutControl.provider?.runningShortcutIDs
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, self.isActive else { return }
                let current = ShortcutControl.provider?.runningShortcutIDs ?? []
                for shortcutId in current.subtracting(previous) {
                    self.publish(.shortcutStarted(shortcutId: shortcutId))
                }
                for shortcutId in previous.subtracting(current) {
                    self.publish(.shortcutFinished(shortcutId: shortcutId))
                }
                self.observeRunningShortcuts(previous: current)
            }
        }
    }

    private func observeRecording(previous: RecordingControl.State?) {
        guard isActive else { return }
        withObservationTracking {
            _ = RecordingControl.provider?.state
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, self.isActive else { return }
                let current = RecordingControl.provider?.state
                switch (previous, current) {
                case (.recording?, .recording?):
                    break
                case (_, .recording?):
                    self.publish(.recordingStarted)
                case (.recording?, .idle?), (.finishing?, .idle?):
                    self.publish(.recordingStopped)
                default:
                    break
                }
                self.observeRecording(previous: current)
            }
        }
    }
}
