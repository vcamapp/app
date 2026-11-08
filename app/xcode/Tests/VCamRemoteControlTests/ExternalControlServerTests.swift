import Foundation
import Network
import Testing
@testable import VCamRemoteControl

@MainActor
@Suite(.serialized)
struct ExternalControlServerTests {
    private static func makeRunningServer(networkAccess: ExternalControlNetworkAccess = .disabled) throws -> (server: ExternalControlServer, port: UInt16) {
        let server = ExternalControlServer()
        let port = UInt16.random(in: 40000..<60000)
        try server.start(port: port, networkAccess: networkAccess)
        return (server, port)
    }

    @Test
    func servesRequestsOverWebSocket() async throws {
        let (server, port) = try Self.makeRunningServer()
        defer {
            server.stop()
        }

        let task = URLSession.shared.webSocketTask(with: URL(string: "ws://127.0.0.1:\(port)")!)
        task.resume()
        try await task.send(.string(#"{"jsonrpc":"2.0","id":1,"method":"app.getInfo","params":{}}"#))
        let message = try await task.receive()
        task.cancel(with: .goingAway, reason: nil)

        guard case .string(let response) = message else {
            Issue.record("Unexpected message: \(message)")
            return
        }
        #expect(response.contains(#""apiVersion":"\#(APISpecification.apiVersion)""#))
    }

#if FEATURE_3
    @Test
    func importUploadTravelsOverBinaryFrames() async throws {
        let (server, port) = try Self.makeRunningServer()
        defer {
            server.stop()
        }

        let task = URLSession.shared.webSocketTask(with: URL(string: "ws://127.0.0.1:\(port)")!)
        task.resume()
        defer {
            task.cancel(with: .goingAway, reason: nil)
        }

        try await task.send(.string(#"{"jsonrpc":"2.0","id":1,"method":"avatar.import.begin","params":{"filename":"upload.vrm"}}"#))
        guard case .string(let beginResponse) = try await task.receive(),
              let importId = beginResponse.split(separator: "\"").last(where: { UUID(uuidString: String($0)) != nil })
        else {
            Issue.record("Unexpected begin response")
            return
        }

        // Not a VRM, so committing must fail with invalid_vrm after the upload arrives
        try await task.send(.data(Data("\(importId)".utf8) + Data("not a vrm".utf8)))
        try await task.send(.string(#"{"jsonrpc":"2.0","id":2,"method":"avatar.import.commit","params":{"importId":"\#(importId)"}}"#))
        guard case .string(let commitResponse) = try await task.receive() else {
            Issue.record("Unexpected commit response")
            return
        }
        #expect(commitResponse.contains(#""code":1006"#))
        #expect(commitResponse.contains("invalid_vrm"))
    }
#endif

    @Test
    func rejectsHandshakesWithOriginHeader() async throws {
        let (server, port) = try Self.makeRunningServer()
        defer {
            server.stop()
        }

        let response = try await Self.handshake(host: "127.0.0.1", port: port, headers: ["Origin: https://example.com"])
        #expect(response.hasPrefix("HTTP/1.1 400"))
    }

    /// ::1 stands in for another device: only the loopback listener binds 127.0.0.1
    @Test
    func networkClientsNeedTheToken() async throws {
        let (server, port) = try Self.makeRunningServer(networkAccess: .enabled(token: "secret"))
        defer {
            server.stop()
        }

        #expect(try await Self.handshake(host: "::1", port: port).hasPrefix("HTTP/1.1 400"))
        #expect(try await Self.handshake(host: "::1", port: port, headers: ["Authorization: Bearer wrong!"]).hasPrefix("HTTP/1.1 400"))
        #expect(try await Self.handshake(host: "::1", port: port, headers: ["Authorization: Bearer secret"]).hasPrefix("HTTP/1.1 101"))
        #expect(try await Self.handshake(host: "127.0.0.1", port: port).hasPrefix("HTTP/1.1 101"))
    }

    @Test
    func networkClientsConnectWithoutTokenWhenNotRequired() async throws {
        let (server, port) = try Self.makeRunningServer(networkAccess: .enabled(token: nil))
        defer {
            server.stop()
        }

        #expect(try await Self.handshake(host: "::1", port: port).hasPrefix("HTTP/1.1 101"))
        #expect(try await Self.handshake(host: "::1", port: port, headers: ["Origin: https://example.com"]).hasPrefix("HTTP/1.1 400"))
    }

    @Test
    func restartingRebindsBothListeners() async throws {
        let (server, port) = try Self.makeRunningServer(networkAccess: .enabled(token: "old"))
        defer {
            server.stop()
        }
        let client = URLSession.shared.webSocketTask(with: URL(string: "ws://127.0.0.1:\(port)")!)
        client.resume()
        defer {
            client.cancel(with: .goingAway, reason: nil)
        }
        try await client.send(.string(#"{"jsonrpc":"2.0","id":1,"method":"app.getInfo","params":{}}"#))
        _ = try await client.receive()

        try await server.restart(port: port, networkAccess: .enabled(token: "new"))
        #expect(server.isRunning)

        #expect(try await Self.handshake(host: "127.0.0.1", port: port).hasPrefix("HTTP/1.1 101"))
        #expect(try await Self.handshake(host: "::1", port: port, headers: ["Authorization: Bearer old"]).hasPrefix("HTTP/1.1 400"))
        #expect(try await Self.handshake(host: "::1", port: port, headers: ["Authorization: Bearer new"]).hasPrefix("HTTP/1.1 101"))
    }

    @Test
    func overlappingRestartsKeepTheLastSettings() async throws {
        let (server, port) = try Self.makeRunningServer(networkAccess: .enabled(token: "first"))
        defer {
            server.stop()
        }

        async let first: Void = server.restart(port: port, networkAccess: .enabled(token: "second"))
        async let second: Void = server.restart(port: port, networkAccess: .enabled(token: "third"))
        _ = try await (first, second)

        #expect(try await Self.handshake(host: "127.0.0.1", port: port).hasPrefix("HTTP/1.1 101"))
        #expect(try await Self.handshake(host: "::1", port: port, headers: ["Authorization: Bearer third"]).hasPrefix("HTTP/1.1 101"))
    }

    @Test
    func stoppingDuringRestartKeepsTheServerStopped() async throws {
        let (server, port) = try Self.makeRunningServer(networkAccess: .enabled(token: "token"))

        let restart = server.scheduleRestart(port: port, networkAccess: .enabled(token: "token"))
        server.stop()
        try await restart.value

        #expect(!server.isRunning)
        let response = try? await Self.handshake(host: "127.0.0.1", port: port)
        #expect(response?.hasPrefix("HTTP/1.1 101") != true)
    }

    /// The rejection is an HTTP 400 on the raw socket, so read the status line instead of
    /// waiting for a WebSocket client to give up
    private static func handshake(host: NWEndpoint.Host, port: UInt16, headers: [String] = []) async throws -> String {
        let lines = [
            "GET / HTTP/1.1",
            "Host: localhost",
            "Upgrade: websocket",
            "Connection: Upgrade",
            "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==",
            "Sec-WebSocket-Version: 13",
        ] + headers
        let request = (lines + ["", ""]).joined(separator: "\r\n")
        return try await exchange(Data(request.utf8), host: host, port: port)
    }

    /// Sends `request` over a plain TCP connection and returns the first bytes the server answers with
    private static func exchange(_ request: Data, host: NWEndpoint.Host, port: UInt16) async throws -> String {
        let connection = NWConnection(host: host, port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
        defer {
            connection.cancel()
        }
        connection.start(queue: .main)
        return try await withCheckedThrowingContinuation { continuation in
            connection.send(content: request, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: String(decoding: data ?? Data(), as: UTF8.self))
                    }
                }
            })
        }
    }
}
