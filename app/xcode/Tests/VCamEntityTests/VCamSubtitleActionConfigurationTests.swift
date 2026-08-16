import Testing
import Foundation
@testable import VCamEntity

@Suite
struct VCamSubtitleActionConfigurationTests {
    /// The action was called a message before it became the subtitle, and shortcuts saved
    /// back then have to keep working
    @Test
    func decodesTheKeysSavedBeforeTheRename() throws {
        let json = """
        {"message":{"configuration":{"id":"3F2504E0-4F89-11D3-9A0C-0305E82C3301","message":"Hello"}}}
        """
        let configuration = try JSONDecoder().decode(AnyVCamActionConfiguration.self, from: Data(json.utf8))
        guard case let .message(subtitle) = configuration else {
            Issue.record("expected a subtitle action, got \(configuration)")
            return
        }
        #expect(subtitle.text == "Hello")
    }

    @Test
    func keepsEncodingTheKeysItWasSavedWith() throws {
        let configuration = VCamSubtitleActionConfiguration(text: "Hello").erased()
        let json = String(decoding: try JSONEncoder().encode(configuration), as: UTF8.self)
        #expect(json.contains("\"message\""))
        #expect(!json.contains("\"text\""))
    }
}
