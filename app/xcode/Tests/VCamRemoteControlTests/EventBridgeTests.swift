import Foundation
import Observation
import Testing
import VCamControl
import VCamData
import VCamEntity
@testable import VCamRemoteControl
import VCamTrackingCore

@MainActor
@Observable
private final class MockTrackingProvider: TrackingControlling {
    var status = ConnectionStatus.disconnected

    var sources: [TrackingControl.Source] {
        [.init(id: "vcamMotion", status: status)]
    }
}

@MainActor
@Observable
private final class MockObjectProvider: SceneObjectControlling {
    var objects: [SceneObjectControl.Object] = []
    var defaultTextConfiguration: TextObjectConfiguration { .init() }
    var textPresets: [SceneObjectControl.TextPreset] { [] }
    var fontNames: [String] { [] }
    var subtitleStyle: SceneObjectControl.SubtitleStyle { .init(configuration: .init(), x: 0, bottomY: 0, size: 1) }

    func update(id: Int32, change: SceneObjectControl.Change) throws {}
    func animatePlacement(id: Int32, placement: SceneObjectControl.PlacementChange, animation: ControlAnimation) async throws {}
    func animateVisibility(id: Int32, isHidden: Bool, animation: ControlAnimation) async throws {}
    func animateSubtitleStyle(_ style: SceneObjectControl.SubtitleStyle, animation: ControlAnimation) async {}
    func move(id: Int32, toIndex index: Int) throws {}
    func duplicate(id: Int32) async throws -> Int32 { id }
    func remove(id: Int32) throws {}
    func applyingTextPreset(id: String, to configuration: TextObjectConfiguration) throws -> TextObjectConfiguration { configuration }
    func addText(_ configuration: TextObjectConfiguration) -> Int32 { 0 }
    func textConfiguration(id: Int32) throws -> TextObjectConfiguration { .init() }
    func updateText(id: Int32, configuration: TextObjectConfiguration) throws {}
    func setSubtitleStyle(_ style: SceneObjectControl.SubtitleStyle) {}
    func addImage(fileURL: URL) throws -> Int32 { 0 }
    func addWeb(url: URL, size: CGSize, fps: Int) -> Int32 { 0 }
    func updateWeb(id: Int32, url: URL?, size: CGSize?, fps: Int?) throws {}
    func addVideo(fileURL: URL, isLooping: Bool, isMuted: Bool) async throws -> Int32 { 0 }
    func videoState(id: Int32) async throws -> SceneObjectControl.VideoState { throw SceneObjectControlError.notFound }
    func updateVideo(id: Int32, change: SceneObjectControl.VideoChange) throws {}
}

@MainActor
@Observable
private final class MockShortcutProvider: ShortcutControlling {
    var shortcuts: [VCamShortcut] = []
    var runningShortcutIDs: Set<UUID> = []

    func perform(_ shortcut: VCamShortcut) async throws {}
}

@MainActor
@Observable
private final class MockRecordingProvider: RecordingControlling {
    var state = RecordingControl.State.idle

    func start() async throws {}
    func stop() async {}
}

// Serialized: the bridge swaps the global AvatarControl.onLoad hook
@MainActor
@Suite(.serialized)
struct EventBridgeTests {
    private final class Recorder {
        var received: [VCamNotification] = []
    }

    private func makeBridge() -> (bridge: EventBridge, uniState: UniState, recorder: Recorder) {
        let uniState = UniState()
        let publisher = EventPublisher()
        let recorder = Recorder()
        let connectionID = UUID()
        publisher.connect(id: connectionID) { body in
            if let notification = try? VCamNotification.decode(body) {
                recorder.received.append(notification)
            }
        }
        publisher.subscribe(id: connectionID, events: nil)
        return (EventBridge(uniState: uniState, eventPublisher: publisher), uniState, recorder)
    }

    /// publish is delivered through two levels of MainActor tasks
    private func drainMainActor() async {
        for _ in 0..<5 {
            await Task.yield()
        }
    }

    @Test
    func motionStateChangesPublishStartAndStop() async throws {
        let (bridge, uniState, recorder) = makeBridge()
        bridge.start()
        defer {
            bridge.stop()
        }

        uniState.isMotionPlaying = ["builtin:hi": true]
        await drainMainActor()
        #expect(recorder.received == [.motionStarted(motionId: "builtin:hi")])

        uniState.isMotionPlaying = ["builtin:hi": false]
        await drainMainActor()
        #expect(recorder.received == [
            .motionStarted(motionId: "builtin:hi"),
            .motionStopped(motionId: "builtin:hi"),
        ])
    }

    @Test
    func subtitleChangesPublishTheNewText() async throws {
        let (bridge, uniState, recorder) = makeBridge()
        bridge.start()
        defer {
            bridge.stop()
        }

        uniState.subtitle = "こんにちは"
        await drainMainActor()
        // Clearing is a change like any other, so subscribers see the empty text
        uniState.subtitle = ""
        await drainMainActor()
        #expect(recorder.received == [.subtitleChanged(text: "こんにちは"), .subtitleChanged(text: "")])
    }

    @Test
    func expressionChangesPublishTheNewName() async throws {
        let (bridge, uniState, recorder) = makeBridge()
        uniState.expressions = [.init(name: "Joy"), .init(name: "Angry")]
        bridge.start()
        defer {
            bridge.stop()
        }

        uniState.currentExpressionName = "Angry"
        await drainMainActor()
        #expect(recorder.received == [.expressionChanged(expressions: [ExpressionWeight(name: "Angry", weight: 1)])])
    }

    @Test
    func objectChangesPublishWhatChanged() async throws {
        func object(_ id: Int32, name: String = "") -> SceneObjectControl.Object {
            .init(id: id, kind: .text, name: name, isHidden: false, isLocked: false, placement: nil)
        }
        let provider = MockObjectProvider()
        provider.objects = [object(1), object(2)]
        let originalProvider = SceneObjectControl.provider
        SceneObjectControl.provider = provider
        defer {
            SceneObjectControl.provider = originalProvider
        }
        let (bridge, _, recorder) = makeBridge()
        bridge.start()
        defer {
            bridge.stop()
        }

        provider.objects = [object(1, name: "Renamed"), object(3)]
        await drainMainActor()

        #expect(recorder.received == [.objectsChanged(added: [3], changed: [1], removed: [2])])
    }

    @Test
    func clearingTheExpressionPublishesNoName() async throws {
        let (bridge, uniState, recorder) = makeBridge()
        uniState.currentExpressionName = "Joy"
        bridge.start()
        defer {
            bridge.stop()
        }

        uniState.currentExpressionName = nil
        await drainMainActor()
        #expect(recorder.received == [.expressionChanged(expressions: [])])
    }

    @Test
    func trackingPublishesOnlyEnteringAndLeavingConnected() async throws {
        let provider = MockTrackingProvider()
        let originalProvider = TrackingControl.provider
        TrackingControl.provider = provider
        defer {
            TrackingControl.provider = originalProvider
        }
        let (bridge, _, recorder) = makeBridge()
        bridge.start()
        defer {
            bridge.stop()
        }

        provider.status = .connecting
        await drainMainActor()
        #expect(recorder.received.isEmpty)

        provider.status = .connected
        await drainMainActor()
        #expect(recorder.received == [.trackingConnected(sourceId: "vcamMotion")])

        provider.status = .connecting
        await drainMainActor()
        #expect(recorder.received == [
            .trackingConnected(sourceId: "vcamMotion"),
            .trackingDisconnected(sourceId: "vcamMotion"),
        ])
    }

    @Test
    func avatarLoadHookPublishes() async throws {
        let (bridge, _, recorder) = makeBridge()
        bridge.start()
        defer {
            bridge.stop()
        }

        let avatarId = UUID()
        AvatarControl.onLoad?(avatarId)
        await drainMainActor()
        #expect(recorder.received == [.avatarLoaded(avatarId: avatarId)])
    }

    @Test
    func stopEndsPublishing() async throws {
        let (bridge, uniState, recorder) = makeBridge()
        bridge.start()
        bridge.stop()

        uniState.isMotionPlaying = ["builtin:hi": true]
        await drainMainActor()
        #expect(recorder.received.isEmpty)
    }

    @Test
    func shortcutChangesPublishTheListAndRuns() async throws {
        var shortcut = VCamShortcut.create()
        let provider = MockShortcutProvider()
        provider.shortcuts = [shortcut]
        let originalProvider = ShortcutControl.provider
        ShortcutControl.provider = provider
        defer {
            ShortcutControl.provider = originalProvider
        }
        let (bridge, _, recorder) = makeBridge()
        bridge.start()
        defer {
            bridge.stop()
        }

        // The actions are not part of what the API shows
        shortcut.configurations = [.wait(configuration: .default)]
        provider.shortcuts = [shortcut]
        await drainMainActor()
        shortcut.title = "Wave"
        provider.shortcuts = [shortcut]
        await drainMainActor()
        provider.runningShortcutIDs = [shortcut.id]
        await drainMainActor()
        provider.runningShortcutIDs = []
        await drainMainActor()

        #expect(recorder.received == [
            .shortcutsChanged(shortcuts: [Shortcut(id: shortcut.id, title: "Wave")]),
            .shortcutStarted(shortcutId: shortcut.id),
            .shortcutFinished(shortcutId: shortcut.id),
        ])
    }

    @Test
    func recordingPublishesWhenItStartsAndWhenItsFileIsWritten() async throws {
        let provider = MockRecordingProvider()
        let originalProvider = RecordingControl.provider
        RecordingControl.provider = provider
        defer {
            RecordingControl.provider = originalProvider
        }
        let (bridge, _, recorder) = makeBridge()
        bridge.start()
        defer {
            bridge.stop()
        }

        provider.state = .recording(startedAt: .now)
        await drainMainActor()
        provider.state = .finishing
        await drainMainActor()
        #expect(recorder.received == [.recordingStarted])

        provider.state = .idle
        await drainMainActor()
        #expect(recorder.received == [.recordingStarted, .recordingStopped])
    }
}
