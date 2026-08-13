import Foundation

/// Delivers server-to-client notifications to subscribed connections.
/// The transport layer registers a connection with `connect`, and the
/// connection receives nothing until it opts in via `events.subscribe`.
@MainActor
package final class EventPublisher {
    package static let shared = EventPublisher()

    private enum Subscription {
        case none
        case all
        case events(Set<String>)

        func contains(_ method: String) -> Bool {
            switch self {
            case .none: false
            case .all: true
            case .events(let events): events.contains(method)
            }
        }
    }

    private struct Subscriber {
        var send: (Data) async -> Void
        var subscription: Subscription = .none
    }

    private var subscribers: [UUID: Subscriber] = [:]

    package init() {}

    package func connect(id: UUID, send: @escaping (Data) async -> Void) {
        subscribers[id] = Subscriber(send: send)
    }

    package func disconnect(id: UUID) {
        subscribers[id] = nil
    }

    /// nil events subscribes to all events
    package func subscribe(id: UUID, events: [String]?) {
        subscribers[id]?.subscription = events.map { .events(Set($0)) } ?? .all
    }

    package func publish(_ notification: VCamNotification) async {
        let recipients = subscribers.values.filter { $0.subscription.contains(notification.method) }
        guard !recipients.isEmpty, let body = try? notification.body() else { return }
        for recipient in recipients {
            await recipient.send(body)
        }
    }
}
