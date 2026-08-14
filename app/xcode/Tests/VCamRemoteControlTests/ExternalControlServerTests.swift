import Foundation
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

    @Test
    func rejectsHandshakesWithOriginHeader() async throws {
        let (server, port) = try Self.makeRunningServer()
        defer {
            server.stop()
        }

        var request = URLRequest(url: URL(string: "ws://127.0.0.1:\(port)")!)
        request.setValue("https://example.com", forHTTPHeaderField: "Origin")
        // The rejected handshake never completes, so bound the wait
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 3
        let task = URLSession(configuration: configuration).webSocketTask(with: request)
        task.resume()
        await #expect(throws: (any Error).self) {
            try await task.send(.string(#"{"jsonrpc":"2.0","id":1,"method":"app.getInfo","params":{}}"#))
            _ = try await task.receive()
        }
        task.cancel(with: .goingAway, reason: nil)
    }
}
