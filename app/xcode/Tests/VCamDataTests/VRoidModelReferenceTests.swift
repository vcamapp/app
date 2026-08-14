import Foundation
import Testing
@testable import VCamData

@Suite
struct VRoidModelReferenceTests {
    @Test
    func lastUsedRoundTripsAndClears() {
        let original = VRoidModelReference.lastUsed
        defer { VRoidModelReference.lastUsed = original }

        let reference = VRoidModelReference(characterModelID: "model-1", characterModelVersionID: "version-1")
        VRoidModelReference.lastUsed = reference
        #expect(VRoidModelReference.lastUsed == reference)

        VRoidModelReference.lastUsed = nil
        #expect(VRoidModelReference.lastUsed == nil)
        #expect(UserDefaults.standard.object(forKey: UserDefaults.Key<VRoidModelReference?>.lastVRoidModel.rawValue) == nil)
    }
}
