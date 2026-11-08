import Foundation
import Network
import Observation
import VCamControl
import VCamData
import VCamLogger

package enum ExternalControlServerError: Error {
    case invalidPort
}

/// The WebSocket server exposing the VCam RPC API.
/// It always listens on 127.0.0.1, and also on every interface when network access is on.
/// Both reject handshakes carrying an Origin header so that web pages cannot reach the API from a browser.
@MainActor
@Observable
package final class ExternalControlServer {
    package static let shared = ExternalControlServer()

    private static let maximumMessageSize = 1024 * 1024
    private static let maximumConnectionCount = 8

    package private(set) var isRunning = false

    @ObservationIgnored private var listeners: [NWListener] = []
    @ObservationIgnored private var connections: [UUID: ExternalControlConnection] = [:]
    @ObservationIgnored private let eventBridge = EventBridge()
    @ObservationIgnored private var pendingRestart: Task<Void, any Error>?
    /// Lets a restart that was waiting tell that the user stopped the server meanwhile
    @ObservationIgnored private var stopCount = 0

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
        try start(port: Self.savedPort(), networkAccess: .saved)
    }

    /// Applies changed settings to the running server, dropping its clients
    package func restartWithSavedPort() async throws {
        try await restart(port: Self.savedPort(), networkAccess: .saved)
    }

    func restart(port: UInt16, networkAccess: ExternalControlNetworkAccess) async throws {
        try await scheduleRestart(port: port, networkAccess: networkAccess).value
    }

    /// Runs after any restart still in progress, since overlapping ones would bind the port before the other releases it
    func scheduleRestart(port: UInt16, networkAccess: ExternalControlNetworkAccess) -> Task<Void, any Error> {
        let previous = pendingRestart
        let stopCount = stopCount
        let restart = Task {
            _ = await previous?.result
            let oldListeners = listeners
            listeners.removeAll()
            // Keeps isRunning so the settings do not show the server stopping for the moment it restarts
            stopListening()
            // Binding the port again fails while the old listeners still hold it
            for listener in oldListeners {
                await Self.cancel(listener)
            }
            guard stopCount == self.stopCount else { return }
            try start(port: port, networkAccess: networkAccess)
        }
        pendingRestart = restart
        return restart
    }

    private static func savedPort() throws -> UInt16 {
        guard let port = UInt16(exactly: UserDefaults.standard.value(for: .integrationExternalControlPort)) else {
            throw ExternalControlServerError.invalidPort
        }
        return port
    }

    package func start(port: UInt16, networkAccess: ExternalControlNetworkAccess = .disabled) throws {
        stopListening()
        isRunning = false

        guard let port = NWEndpoint.Port(rawValue: port) else {
            throw ExternalControlServerError.invalidPort
        }
        do {
            listeners.append(try makeListener(port: port, isLoopbackOnly: true, token: nil))
            if case .enabled(let token) = networkAccess {
                // Connections to 127.0.0.1 still reach the loopback listener, which binds the more specific address
                listeners.append(try makeListener(port: port, isLoopbackOnly: false, token: token))
            }
        } catch {
            stopListening()
            throw error
        }
        isRunning = true
        eventBridge.start()
        UploadStaging.shared.removeAll()
    }

    package func stop() {
        stopCount += 1
        stopListening()
        isRunning = false
    }

    private func stopListening() {
        eventBridge.stop()
        for listener in listeners {
            listener.cancel()
        }
        listeners.removeAll()
        for connection in connections.values {
            connection.cancel()
        }
        connections.removeAll()
    }

    /// - Parameter token: Required from every client when set
    private func makeListener(port: NWEndpoint.Port, isLoopbackOnly: Bool, token: String?) throws -> NWListener {
        let parameters = NWParameters.tcp
        if isLoopbackOnly {
            parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: port)
        }
        parameters.allowLocalEndpointReuse = true

        let webSocketOptions = NWProtocolWebSocket.Options()
        webSocketOptions.autoReplyPing = true
        webSocketOptions.maximumMessageSize = Self.maximumMessageSize
        webSocketOptions.setClientRequestHandler(.main) { _, headers in
            // Browsers always send an Origin header; native clients normally do not
            let hasOrigin = headers.contains { $0.name.caseInsensitiveCompare("origin") == .orderedSame }
            let isAuthorized = token.map { ExternalControlToken.authorizes(headers, token: $0) } ?? true
            return .init(status: !hasOrigin && isAuthorized ? .accept : .reject, subprotocol: nil)
        }
        parameters.defaultProtocolStack.applicationProtocols.insert(webSocketOptions, at: 0)

        let listener = try isLoopbackOnly ? NWListener(using: parameters) : NWListener(using: parameters, on: port)
        listener.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in
                self?.accept(connection)
            }
        }
        listener.stateUpdateHandler = { state in
            if case .failed(let error) = state {
                Logger.error(error)
            }
        }
        listener.start(queue: .main)
        return listener
    }

    /// Returns once the listener has released its port
    private static func cancel(_ listener: NWListener) async {
        await withCheckedContinuation { continuation in
            listener.stateUpdateHandler = { state in
                guard case .cancelled = state else { return }
                continuation.resume()
            }
            listener.cancel()
        }
    }

    private func accept(_ connection: NWConnection) {
        guard isRunning, connections.count < Self.maximumConnectionCount else {
            connection.cancel()
            return
        }
        let client = ExternalControlConnection(connection: connection) { [weak self] id in
            self?.connections[id] = nil
            EventPublisher.shared.disconnect(id: id)
            UploadStaging.shared.cancelAll(connectionID: id)
        }
        connections[client.id] = client
        EventPublisher.shared.connect(id: client.id) { [weak client] body in
            client?.send(body)
        }
        client.start()
    }
}

/// Whether clients on other devices may connect, and the token they must present
package enum ExternalControlNetworkAccess: Equatable, Sendable {
    case disabled
    /// - Parameter token: nil accepts clients without one
    case enabled(token: String?)

    static var saved: Self {
        guard UserDefaults.standard.value(for: .integrationExternalControlNetworkAccess) else { return .disabled }
        let requiresToken = UserDefaults.standard.value(for: .integrationExternalControlRequiresToken)
        return .enabled(token: requiresToken ? ExternalControlToken.saved() : nil)
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
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
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
        connection.receiveMessage { [weak self] content, context, _, error in
            let metadata = context?.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata
            let isBinary = metadata?.opcode == .binary
            Task { @MainActor in
                guard let self else { return }
                guard let content, error == nil else {
                    self.connection.cancel()
                    return
                }
                if isBinary {
                    // Binary frames carry upload chunks (see avatar.import.begin)
                    UploadStaging.shared.receiveFrame(content, connectionID: self.id)
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
