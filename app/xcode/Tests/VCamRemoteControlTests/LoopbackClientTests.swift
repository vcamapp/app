import Foundation
import Testing
import VCamData
@testable import VCamRemoteControl

/// Feeds the generated client straight into the generated server, so the
/// whole request/response cycle is exercised with typed APIs.
private struct LoopbackTransport: JSONRPCTransport {
    let server: VCamServer

    func send(_ body: Data) async throws -> Data {
        await server.handle(body) ?? Data()
    }
}

@MainActor
@Suite(.serialized)
struct LoopbackClientTests {
    private func makeClient() -> VCam {
        let service = VCamAPIService(
            connectionID: UUID(),
            modelManager: ModelManager(models: []),
            uniState: UniState()
        )
        return VCam(transport: LoopbackTransport(server: VCamServer(handler: service)))
    }

    @Test
    func typedRequestsRoundTrip() async throws {
        let client = makeClient()

        let info = try await client.appGetInfo()
        #expect(info.apiVersion == APISpecification.apiVersion)
        #expect(info.capabilities.contains("motion"))

        let state = try await client.stateGet()
        #expect(state.playingMotionIds.isEmpty)

        let avatars = try await client.avatarList()
        #expect(avatars.isEmpty)
    }

    @Test
    func importErrorsAreTyped() async throws {
        let client = makeClient()

        do {
            _ = try await client.avatarImportBegin(filename: "not-a-vrm.txt")
            Issue.record("Expected importFailed")
        } catch let VCamError.importFailed(error) {
            #expect(error.code == 1007)
        }

        do {
            _ = try await client.avatarImportCommit(importId: UUID())
            Issue.record("Expected importNotFound")
        } catch let VCamError.importNotFound(error) {
            #expect(error.code == 1005)
            #expect(error.data == .object(["code": .string("import_not_found")]))
        }
    }

    @Test
    func declaredErrorsAreTyped() async throws {
        let client = makeClient()
        do {
            _ = try await client.motionPlay(motionId: "builtin:not-registered")
            Issue.record("Expected motionNotFound")
        } catch let VCamError.motionNotFound(error) {
            #expect(error.code == 1002)
            #expect(error.data == .object(["code": .string("motion_not_found")]))
        }
    }
}
