import Foundation
import Testing
@testable import VCamRemoteControl

@MainActor
@Suite
struct EventPublisherTests {
    @Test
    func deliversOnlySubscribedEvents() async throws {
        let publisher = EventPublisher()
        let connectionID = UUID()
        var received: [Data] = []
        publisher.connect(id: connectionID) { received.append($0) }

        // Nothing is delivered before events.subscribe
        await publisher.publish(.motionStarted(motionId: "builtin:hi"))
        #expect(received.isEmpty)

        publisher.subscribe(id: connectionID, events: ["motion.started"])
        await publisher.publish(.motionStarted(motionId: "builtin:hi"))
        await publisher.publish(.sceneLoaded(sceneId: 1))
        #expect(received.count == 1)

        let notification = try VCamNotification.decode(#require(received.first))
        #expect(notification == .motionStarted(motionId: "builtin:hi"))
    }

    @Test
    func nilSubscribesToAllEventsAndDisconnectStops() async {
        let publisher = EventPublisher()
        let connectionID = UUID()
        var received: [Data] = []
        publisher.connect(id: connectionID) { received.append($0) }
        publisher.subscribe(id: connectionID, events: nil)

        await publisher.publish(.appReady)
        await publisher.publish(.expressionChanged(name: "Joy"))
        #expect(received.count == 2)

        publisher.disconnect(id: connectionID)
        await publisher.publish(.appReady)
        #expect(received.count == 2)
    }
}
