import Foundation
import Network
import VCamBridge
import VCamLogger
import VCamEntity

@MainActor
final class UDPDatagramSession {
    private var listener: NWListener?
    private var connection: NWConnection?

    var isRunning: Bool { listener != nil }

    func start(
        on port: NWEndpoint.Port,
        service: NWListener.Service? = nil,
        queue: DispatchQueue,
        onEnded: @escaping @MainActor @Sendable () -> Void,
        onConnectionStarted: @escaping @MainActor @Sendable () -> Void = {},
        onReady: @escaping @MainActor @Sendable () -> Void,
        onData: @escaping @MainActor @Sendable (Data) -> Void
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
    }

    private func replaceConnection(with connection: NWConnection) {
        self.connection?.stateUpdateHandler = nil
        self.connection?.cancel()
        self.connection = connection
    }

    private func handle(
        _ state: NWConnection.State,
        from connection: NWConnection,
        onEnded: @escaping @MainActor @Sendable () -> Void,
        onReady: @escaping @MainActor @Sendable () -> Void,
        onData: @escaping @MainActor @Sendable (Data) -> Void
    ) {
        guard self.connection === connection else { return }
        Self.log(state)
        switch state {
        case .ready:
            onReady()
            connection.receiveDatagrams { [weak self, weak connection] data in
                DispatchQueue.runOnMain {
                    guard let self, let connection, self.connection === connection else { return }
                    onData(data)
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
