import Foundation
import Testing
@testable import VCamEntity

@Suite
struct MotionIDTests {
    @Test
    func builtInRoundTrip() throws {
        let id = MotionID.builtIn(name: "hi")
        #expect(id.rawValue == "builtin:hi")
        #expect(MotionID(rawValue: "builtin:hi") == id)
    }

    @Test
    func importedRoundTrip() throws {
        let uuid = try #require(UUID(uuidString: "550E8400-E29B-41D4-A716-446655440000"))
        let id = MotionID.imported(id: uuid)
        #expect(id.rawValue == "vrma:550E8400-E29B-41D4-A716-446655440000")
        #expect(MotionID(rawValue: id.rawValue) == id)
    }

    @Test
    func invalidRawValue() {
        #expect(MotionID(rawValue: "builtin:") == nil)
        #expect(MotionID(rawValue: "vrma:not-a-uuid") == nil)
        #expect(MotionID(rawValue: "hi") == nil)
        #expect(MotionID(rawValue: "") == nil)
    }
}

@Suite
struct TranslationAxisMaskTests {
    @Test
    func rawValues() {
        #expect(TranslationAxisMask.all.rawValue == 7)
        #expect(TranslationAxisMask([.x, .z]).rawValue == 5)
    }

    @Test
    func codableAsNumber() throws {
        let data = try JSONEncoder().encode(TranslationAxisMask.all)
        #expect(String(data: data, encoding: .utf8) == "7")
        let decoded = try JSONDecoder().decode(TranslationAxisMask.self, from: data)
        #expect(decoded == .all)
    }
}

@Suite
struct ImportedMotionRecordTests {
    @Test
    func decodeWithoutIsLoopDefaultsToFalse() throws {
        let json = """
        {
          "id": "550E8400-E29B-41D4-A716-446655440000",
          "displayName": "Dance",
          "translationAxes": 7
        }
        """
        let record = try JSONDecoder().decode(ImportedMotionRecord.self, from: Data(json.utf8))
        #expect(record.isLoop == false)
        #expect(record.displayName == "Dance")
        #expect(record.translationAxes == .all)
        #expect(record.motionID == "vrma:550E8400-E29B-41D4-A716-446655440000")
    }

    @Test
    func encodeDecodeRoundTrip() throws {
        let record = ImportedMotionRecord(
            displayName: "Greeting",
            translationAxes: [.x, .y],
            isLoop: true
        )
        let decoded = try JSONDecoder().decode(ImportedMotionRecord.self, from: JSONEncoder().encode(record))
        #expect(decoded == record)
    }
}

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
