import Foundation
import Testing
import VCamBridge
import VCamControl

@MainActor
@Suite
struct AvatarControlTests {
    @Test
    func loadFileURLSendsPathWithoutRegistration() {
        let loaded = recordedStringValues {
            AvatarControl.load(vrmFileURL: URL(filePath: "/tmp/avatar.vrm"))
        }
        #expect(loaded.count == 1)
        #expect(loaded.first?.type == .loadVRM)
        #expect(loaded.first?.value == "/tmp/avatar.vrm")
    }
}
