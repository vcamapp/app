import Foundation
import Testing
@testable import VCamEntity

@Suite
struct VCamMotionActionConfigurationTests {
    @Test
    func decodeLegacyMotionKey() throws {
        let json = """
        {
          "id": "550E8400-E29B-41D4-A716-446655440000",
          "motion": "jump"
        }
        """
        let configuration = try JSONDecoder().decode(VCamMotionActionConfiguration.self, from: Data(json.utf8))
        #expect(configuration.motionID == "builtin:jump")
    }

    @Test
    func decodeCurrentFormat() throws {
        let json = """
        {
          "id": "550E8400-E29B-41D4-A716-446655440000",
          "motionID": "vrma:650E8400-E29B-41D4-A716-446655440000"
        }
        """
        let configuration = try JSONDecoder().decode(VCamMotionActionConfiguration.self, from: Data(json.utf8))
        #expect(configuration.motionID == "vrma:650E8400-E29B-41D4-A716-446655440000")
    }

    @Test
    func encodeUsesMotionID() throws {
        var configuration = VCamMotionActionConfiguration()
        configuration.motionID = "builtin:bye"
        let data = try JSONEncoder().encode(configuration)
        let decoded = try JSONDecoder().decode(VCamMotionActionConfiguration.self, from: data)
        #expect(decoded.motionID == "builtin:bye")
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["motion"] == nil)
    }

    @Test
    func decodeMissingMotionFallsBackToDefault() throws {
        let json = """
        {
          "id": "550E8400-E29B-41D4-A716-446655440000"
        }
        """
        let configuration = try JSONDecoder().decode(VCamMotionActionConfiguration.self, from: Data(json.utf8))
        #expect(configuration.motionID == "builtin:hi")
    }
}

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
