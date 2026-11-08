import Foundation
import Testing
@testable import VCamBridge
import VCamControl
import VCamEntity

#if FEATURE_3
extension RecordingWhileSuspendedTests {
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

        @Test
        func theEventWaitsForTheRendererToFinish() {
            var loaded: [UUID?] = []
            AvatarControl.onLoad = { loaded.append($0) }
            defer {
                AvatarControl.onLoad = nil
            }

            AvatarControl.didFinishLoading(succeeded: false)
            #expect(loaded.isEmpty)

            AvatarControl.didFinishLoading(succeeded: true)
            #expect(loaded == [nil])
        }

        @Test
        func aVRoidLoadIsReportedAsOutsideTheLibrary() async throws {
            var loaded: [UUID?] = []
            AvatarControl.onLoad = { loaded.append($0) }
            defer {
                AvatarControl.onLoad = nil
            }
            _ = try await completingModelLoads(errorCode: 0) {
                try await AvatarControl.load(vroidModelFileURL: URL(filePath: "/tmp/vroid.vrm"))
            }
            #expect(loaded.isEmpty)

            AvatarControl.didFinishLoading(succeeded: true)

            #expect(loaded == [nil])
        }
    }
}
#endif
