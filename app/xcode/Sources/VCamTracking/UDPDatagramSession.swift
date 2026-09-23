import Foundation
import Network
import Synchronization
import VCamBridge
import VCamLogger
import VCamEntity
import VCamTrackingCore

@MainActor
final class UDPDatagramSession {
    private var listener: NWListener?
    private var connection: NWConnection?
    /// The receive queue checks this itself: a datagram of a replaced connection still in flight
    /// there would otherwise reach the receiver's per-session state before the main actor drops it
    private let currentConnection = CurrentConnection()

    var isRunning: Bool { listener != nil }

    /// `receive` runs on the receive queue, before the hop to the main actor, so a receiver can
    /// act on a datagram without waiting for a main thread busy drawing. Its result goes to `onData`
    func start<Received: Sendable>(
        on port: NWEndpoint.Port,
        service: NWListener.Service? = nil,
        queue: DispatchQueue,
        onEnded: @escaping @MainActor @Sendable () -> Void,
        onConnectionStarted: @escaping @MainActor @Sendable () -> Void = {},
        onReady: @escaping @MainActor @Sendable () -> Void,
        receive: @escaping @Sendable (Data, _ receivedAt: TimeInterval) -> Received,
        onData: @escaping @MainActor @Sendable (Received) -> Void
    ) throws {
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true

        let listener = try NWListener(using: parameters, on: port)
        listener.service = service
        self.listener = listener

        listener.stateUpdateHandler = { [weak self, weak listener] state in
            switch state {
            case .failed(let error):
                Logger.log("Listener failed: \(error.localizedDescription)")
            case .cancelled:
                Logger.log("Listener cancelled")
            default:
                return
            }
            Task { @MainActor in
                guard let self, let listener, self.listener === listener else { return }
                onEnded()
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in
                guard let self else { return }
                self.replaceConnection(with: connection)
                onConnectionStarted()

                connection.stateUpdateHandler = { [weak self, weak connection] state in
                    Task { @MainActor in
                        guard let self, let connection else { return }
                        self.handle(
                            state,
                            from: connection,
                            onEnded: onEnded,
                            onReady: onReady,
                            receive: receive,
                            onData: onData
                        )
                    }
                }
                connection.start(queue: queue)
            }
        }
        listener.start(queue: queue)
    }

    func stop() {
        if let listener {
            listener.stateUpdateHandler = nil
            listener.newConnectionHandler = nil
            listener.cancel()
            self.listener = nil
        }

        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        currentConnection.set(nil)
    }

    private func replaceConnection(with connection: NWConnection) {
        self.connection?.stateUpdateHandler = nil
        self.connection?.cancel()
        self.connection = connection
        currentConnection.set(connection)
    }

    private func handle<Received: Sendable>(
        _ state: NWConnection.State,
        from connection: NWConnection,
        onEnded: @escaping @MainActor @Sendable () -> Void,
        onReady: @escaping @MainActor @Sendable () -> Void,
        receive: @escaping @Sendable (Data, _ receivedAt: TimeInterval) -> Received,
        onData: @escaping @MainActor @Sendable (Received) -> Void
    ) {
        guard self.connection === connection else { return }
        Self.log(state)
        switch state {
        case .ready:
            onReady()
            let currentConnection = currentConnection
            connection.receiveDatagrams { [weak self, weak connection] data in
                let receivedAt = ProcessInfo.processInfo.systemUptime
                // Recorded here rather than by each receiver, so every protocol gets both timestamps
                TrackingTraceRecorder.shared.recordDatagram(data, time: receivedAt)
                let received = connection.flatMap { currentConnection.is($0) ? receive(data, receivedAt) : nil }
                // Hops even for a dropped datagram: the trace pairs receive and main arrival by order
                DispatchQueue.runOnMain {
                    TrackingTraceRecorder.shared.recordMainArrival()
                    guard let self, let connection, self.connection === connection, let received else { return }
                    onData(received)
                }
            }
        case .cancelled, .failed:
            onEnded()
        case .setup, .preparing, .waiting:
            break
        @unknown default:
            break
        }
    }

    private static func log(_ state: NWConnection.State) {
        switch state {
        case .waiting(let error):
            Logger.log("Connection waiting: \(error.localizedDescription)")
        case .ready:
            Logger.log("Connection ready")
        case .cancelled:
            Logger.log("Connection cancelled")
        case .failed(let error):
            Logger.log("Connection failed: \(error.localizedDescription)")
        case .setup, .preparing:
            break
        @unknown default:
            break
        }
    }
}

private extension NWConnection {
    func receiveDatagrams(_ dataHandler: @escaping @Sendable (Data) -> Void) {
        receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] content, _, _, error in
            guard let self, error == nil else { return }
            if let content, !content.isEmpty {
                dataHandler(content)
            }
            receiveDatagrams(dataHandler)
        }
    }
}

private final class CurrentConnection: Sendable {
    private let identifier = Mutex<ObjectIdentifier?>(nil)

    func set(_ connection: NWConnection?) {
        identifier.withLock { $0 = connection.map(ObjectIdentifier.init) }
    }

    func `is`(_ connection: NWConnection) -> Bool {
        identifier.withLock { $0 == ObjectIdentifier(connection) }
    }
}
