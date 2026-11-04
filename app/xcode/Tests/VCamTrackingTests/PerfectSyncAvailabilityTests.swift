import Testing
import VCamBridge
import VCamData
@testable import VCamTracking

@MainActor
@Suite(.serialized)
struct PerfectSyncAvailabilityTests {
    @Test(arguments: [true, false])
    func syncPublishesWhatTheLoadedModelSupports(_ isSupported: Bool) {
        let mapper = UniBridge.shared.boolMapper
        let originalGetValue = mapper.getValue
        let originalCallback = UniBridge.methodCallback
        defer {
            mapper.getValue = originalGetValue
            UniBridge.methodCallback = originalCallback
        }
        UniBridge.methodCallback = { _, _, _ in }

        mapper.getValue = { $0 == .hasPerfectSyncBlendShape ? !isSupported : false }
        Tracking.shared.syncPerfectSyncAvailability()

        mapper.getValue = { $0 == .hasPerfectSyncBlendShape ? isSupported : false }
        Tracking.shared.syncPerfectSyncAvailability()

        #expect(UniState.shared.hasPerfectSyncBlendShape == isSupported)
    }
}
