import Foundation
import Network
import Testing
@testable import VCamRemoteControl

@MainActor
@Suite(.serialized)
struct ExternalControlServerTests {
    private static func makeRunningServer() throws -> (server: ExternalControlServer, port: UInt16) {
        let server = ExternalControlServer()
        let port = UInt16.random(in: 40000..<60000)
        try server.start(port: port)
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

    /// The rejection is an HTTP 400 on the raw socket, so read the status line instead of
    /// waiting for a WebSocket client to give up
    @Test
    func rejectsHandshakesWithOriginHeader() async throws {
        let (server, port) = try Self.makeRunningServer()
        defer {
            server.stop()
        }

        let handshake = """
        GET / HTTP/1.1\r
        Host: 127.0.0.1\r
        Upgrade: websocket\r
        Connection: Upgrade\r
        Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r
        Sec-WebSocket-Version: 13\r
        Origin: https://example.com\r
        \r

        """
        let response = try await Self.exchange(Data(handshake.utf8), port: port)
        #expect(response.hasPrefix("HTTP/1.1 400"))
    }

    /// Sends `request` over a plain TCP connection and returns the first bytes the server answers with
    private static func exchange(_ request: Data, port: UInt16) async throws -> String {
        let connection = NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
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
