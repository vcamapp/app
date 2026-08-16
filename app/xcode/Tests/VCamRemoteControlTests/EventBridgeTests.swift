import Foundation
import Testing
import VCamControl
import VCamData
@testable import VCamRemoteControl

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

        uniState.currentExpressionIndex = 1
        await drainMainActor()
        #expect(recorder.received == [.expressionChanged(name: "Angry")])
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
}
