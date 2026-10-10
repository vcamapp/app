import Testing
import Foundation
@testable import VCamEntity

@Suite
struct VCamSceneLightingTests {
    @Test
    func sceneSavedBeforeLightingDecodesWithoutIt() throws {
        let json = #"{"id":1,"name":"","objects":[],"aspectRatio":0.5625,"version":2}"#

        let scene = try JSONDecoder().decode(VCamScene.self, from: Data(json.utf8))

        #expect(scene.lighting == nil)
        #expect(scene.aspectRatio == 0.5625)
    }

    @Test
    func sceneWithoutLightingKeepsTheFormatOlderVersionsWrote() throws {
        let scene = VCamScene(id: 1, name: "", objects: [], aspectRatio: 16 / 9)

        let json = try #require(String(data: JSONEncoder().encode(scene), encoding: .utf8))

        #expect(!json.contains("lighting"))
    }

    @Test
    func lightingRoundTrips() throws {
        let lighting = VCamScene.Lighting(
            azimuth: 120, elevation: 30, shadow: 0.5, shadowColor: .init(red: 0.6, green: 0.7, blue: 1),
            rim: .init(color: .white, intensity: 1.5)
        )
        let scene = VCamScene(id: 1, name: "", objects: [], aspectRatio: 16 / 9, lighting: lighting)

        let decoded = try JSONDecoder().decode(VCamScene.self, from: JSONEncoder().encode(scene))

        #expect(decoded.lighting == lighting)
    }
}
