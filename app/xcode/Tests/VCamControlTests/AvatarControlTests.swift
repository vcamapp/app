import Foundation
import Testing
@testable import VCamBridge
import VCamControl
import VCamEntity

@MainActor
@Suite
struct AvatarControlTests {
    @Test
    func loadVRoidModelResumesOnEngineCompletion() async throws {
        let calls = try await completingModelLoads(errorCode: 0) {
            try await AvatarControl.load(vroidModelFileURL: URL(filePath: "/tmp/vroid.vrm"))
        }
        #expect(calls.map(\.path) == ["/tmp/vroid.vrm"])
        #expect(calls.first?.source == .vroidHub)
    }

    @Test
    func loadVRoidModelThrowsOnEngineFailure() async {
        await #expect(throws: ModelLoadError.loadFailed) {
            _ = try await completingModelLoads(errorCode: 1) {
                try await AvatarControl.load(vroidModelFileURL: URL(filePath: "/tmp/vroid.vrm"))
            }
        }
    }
}
