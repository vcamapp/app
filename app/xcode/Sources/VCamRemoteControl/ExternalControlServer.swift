import Foundation
import Network
import Observation
import VCamData
import VCamLogger

package enum ExternalControlServerError: Error {
    case invalidPort
}

/// The localhost WebSocket server exposing the VCam RPC API.
/// It binds to 127.0.0.1 only, and rejects handshakes carrying an Origin
/// header so that web pages cannot reach the API from a browser.
@MainActor
@Observable
package final class ExternalControlServer {
    package static let shared = ExternalControlServer()

    private static let maximumMessageSize = 1024 * 1024
    private static let maximumConnectionCount = 8

    package private(set) var isRunning = false

    @ObservationIgnored private var listener: NWListener?
    @ObservationIgnored private var connections: [UUID: ExternalControlConnection] = [:]
    @ObservationIgnored private let eventBridge = EventBridge()

    package init() {}

    /// Starts the server when the user has enabled it, rolling the setting
    /// back on failure so the UI does not claim the server is running
    package func startIfEnabled() {
        guard UserDefaults.standard.value(for: .integrationExternalControl) else { return }
        do {
            try startWithSavedPort()
        } catch {
            Logger.error(error)
            UserDefaults.standard.set(false, for: .integrationExternalControl)
        }
    }

    package func startWithSavedPort() throws {
        guard let port = UInt16(exactly: UserDefaults.standard.value(for: .integrationExternalControlPort)) else {
            throw ExternalControlServerError.invalidPort
        }
        try start(port: port)
    }

    package func start(port: UInt16) throws {
        stop()

        guard let port = NWEndpoint.Port(rawValue: port) else {
            throw ExternalControlServerError.invalidPort
        }
        let parameters = NWParameters.tcp
        // Never expose the API beyond this Mac
        parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host: .ipv4(.loopback), port: port)
        parameters.allowLocalEndpointReuse = true

        let webSocketOptions = NWProtocolWebSocket.Options()
        webSocketOptions.autoReplyPing = true
        webSocketOptions.maximumMessageSize = Self.maximumMessageSize
        // Browsers always send an Origin header; native clients normally do not
        webSocketOptions.setClientRequestHandler(.main) { _, headers in
            let hasOrigin = headers.contains { $0.name.lowercased() == "origin" }
            return .init(status: hasOrigin ? .reject : .accept, subprotocol: nil)
        }
        parameters.defaultProtocolStack.applicationProtocols.insert(webSocketOptions, at: 0)

        let listener = try NWListener(using: parameters)
        listener.newConnectionHandler = { connection in
            Task { @MainActor [weak self] in
                self?.accept(connection)
            }
        }
        listener.start(queue: .main)
        self.listener = listener
        isRunning = true
        eventBridge.start()
        AvatarImportManager.shared.removeAllStaging()
    }

    package func stop() {
        eventBridge.stop()
        listener?.cancel()
        listener = nil
        for connection in connections.values {
            connection.cancel()
        }
        connections.removeAll()
        isRunning = false
    }

    private func accept(_ connection: NWConnection) {
        guard isRunning, connections.count < Self.maximumConnectionCount else {
            connection.cancel()
            return
        }
        let client = ExternalControlConnection(connection: connection) { [weak self] id in
            self?.connections[id] = nil
            EventPublisher.shared.disconnect(id: id)
            AvatarImportManager.shared.cancelAll(connectionID: id)
        }
        connections[client.id] = client
        EventPublisher.shared.connect(id: client.id) { [weak client] body in
            client?.send(body)
        }
        client.start()
    }
}

/// One WebSocket client: its own API service (event subscriptions are
/// per-connection) fed by a receive loop.
@MainActor
private final class ExternalControlConnection {
    nonisolated let id = UUID()

    private let connection: NWConnection
    private let server: VCamServer
    private let onClose: @MainActor (UUID) -> Void

    init(connection: NWConnection, onClose: @escaping @MainActor (UUID) -> Void) {
        self.connection = connection
        self.server = VCamServer(handler: VCamAPIService(connectionID: id))
        self.onClose = onClose
    }

    func start() {
        connection.stateUpdateHandler = { state in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch state {
                case .failed, .cancelled:
                    self.onClose(self.id)
                default:
                    break
                }
            }
        }
        connection.start(queue: .main)
        receiveNextMessage()
    }

    func cancel() {
        connection.cancel()
    }

    func send(_ body: Data) {
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "message", metadata: [metadata])
        connection.send(content: body, contentContext: context, isComplete: true, completion: .idempotent)
    }

    private func receiveNextMessage() {
        connection.receiveMessage { content, context, _, error in
            let metadata = context?.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata
            let isBinary = metadata?.opcode == .binary
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard let content, error == nil else {
                    self.connection.cancel()
                    return
                }
                if isBinary {
                    // Binary frames carry avatar upload chunks (see avatar.import.begin)
                    AvatarImportManager.shared.receiveFrame(content, connectionID: self.id)
                } else {
                    self.handle(content)
                }
                self.receiveNextMessage()
            }
        }
    }

    private func handle(_ body: Data) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let response = await self.server.handle(body) {
                self.send(response)
            }
        }
    }
}
