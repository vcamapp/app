import Testing
import Foundation
@testable import VCamEntity

@Suite
struct VCamSceneMigrationTests {
    private func makeScene(objects: [VCamScene.Object], version: Int?) -> VCamScene {
        var scene = VCamScene(id: 1, name: "test", objects: objects, aspectRatio: 16 / 9)
        scene.version = version
        return scene
    }

    private func makeTexture(width: Float, height: Float, crop: VCamScene.Plane) -> VCamScene.RenderTexture {
        .init(width: width, height: height, region: .init(x: 0, y: 0, width: 0.5, height: 0.5), crop: crop, filter: nil)
    }

    private func makeObject(id: Int32 = 1, type: VCamScene.ObjectType) -> VCamScene.Object {
        .init(id: id, name: "obj", type: type, isHidden: false, isLocked: false)
    }

    @Test
    func v1ScreenCropIsScaledToUnitRect() throws {
        let texture = makeTexture(width: 2000, height: 1000, crop: .init(x: 0.1, y: 0.2, width: 0.5, height: 0.25))
        let object = makeObject(type: .screen(id: "display", state: .init(captureType: .display, texture: texture)))
        var scene = makeScene(objects: [object], version: nil)

        scene.migrateToCurrentVersion()

        guard case let .screen(_, state) = scene.objects[0].type else {
            Issue.record("unexpected object type")
            return
        }
        #expect(state.texture.crop.x == 0.1)
        #expect(state.texture.crop.y == 0.4)
        #expect(state.texture.crop.width == 0.5)
        #expect(state.texture.crop.height == 0.5)
        #expect(scene.version == VCamScene.currentVersion)
    }

    @Test
    func v1UncroppedFullFrameBecomesUnitRect() throws {
        // A full 16:9 frame was stored as height 0.5625 in the width-normalized format
        let texture = makeTexture(width: 1920, height: 1080, crop: .init(x: 0, y: 0, width: 1, height: 0.5625))
        let object = makeObject(type: .captureDevice(id: "camera", state: texture))
        var scene = makeScene(objects: [object], version: nil)

        scene.migrateToCurrentVersion()

        guard case let .captureDevice(_, state) = scene.objects[0].type else {
            Issue.record("unexpected object type")
            return
        }
        #expect(state.crop.x == 0)
        #expect(state.crop.y == 0)
        #expect(state.crop.width == 1)
        #expect(abs(state.crop.height - 1) < 1e-5)
    }

    @Test
    func v1WebCropIsResetToUnitRect() throws {
        // v1 normalized web crops by the longer side, so they are reset instead of converted
        let texture = makeTexture(width: 800, height: 1200, crop: .init(x: 0, y: 0, width: 2 / 3, height: 1))
        let object = makeObject(type: .web(state: .init(url: nil, path: nil, fps: 30, css: nil, js: nil, texture: texture)))
        var scene = makeScene(objects: [object], version: nil)

        scene.migrateToCurrentVersion()

        guard case let .web(state) = scene.objects[0].type else {
            Issue.record("unexpected object type")
            return
        }
        #expect(state.texture.crop.x == 0)
        #expect(state.texture.crop.y == 0)
        #expect(state.texture.crop.width == 1)
        #expect(state.texture.crop.height == 1)
    }

    @Test
    func currentVersionSceneIsNotMigratedTwice() throws {
        let texture = makeTexture(width: 2000, height: 1000, crop: .init(x: 0.1, y: 0.4, width: 0.5, height: 0.5))
        let object = makeObject(type: .screen(id: "display", state: .init(captureType: .display, texture: texture)))
        var scene = makeScene(objects: [object], version: VCamScene.currentVersion)

        scene.migrateToCurrentVersion()

        guard case let .screen(_, state) = scene.objects[0].type else {
            Issue.record("unexpected object type")
            return
        }
        #expect(state.texture.crop.y == 0.4)
        #expect(state.texture.crop.height == 0.5)
    }

    @Test
    func zeroHeightTextureKeepsCropUntouched() throws {
        let texture = makeTexture(width: 2000, height: 0, crop: .init(x: 0.1, y: 0.2, width: 0.5, height: 0.25))
        let object = makeObject(type: .captureDevice(id: "camera", state: texture))
        var scene = makeScene(objects: [object], version: nil)

        scene.migrateToCurrentVersion()

        guard case let .captureDevice(_, state) = scene.objects[0].type else {
            Issue.record("unexpected object type")
            return
        }
        #expect(state.crop.y == 0.2)
        #expect(state.crop.height == 0.25)
        #expect(scene.version == VCamScene.currentVersion)
    }

    @Test
    func decodingSceneWithoutVersionMigratesAsV1() throws {
        // Simulates a scene saved by an old app version, which has no version field
        let json = """
        {
          "id": 1,
          "name": "old",
          "objects": [
            {
              "id": 2,
              "name": "screen",
              "type": {
                "screen": {
                  "id": "display",
                  "state": {
                    "captureType": "display",
                    "texture": {
                      "width": 1920,
                      "height": 1080,
                      "region": { "x": 0, "y": 0, "width": 0.5, "height": 0.5 },
                      "crop": { "x": 0.25, "y": 0.140625, "width": 0.5, "height": 0.28125 }
                    }
                  }
                }
              }
            }
          ]
        }
        """
        var scene = try JSONDecoder().decode(VCamScene.self, from: Data(json.utf8))
        #expect(scene.version == nil)

        scene.migrateToCurrentVersion()

        guard case let .screen(_, state) = scene.objects[0].type else {
            Issue.record("unexpected object type")
            return
        }
        #expect(abs(state.texture.crop.y - 0.25) < 1e-5)
        #expect(abs(state.texture.crop.height - 0.5) < 1e-5)
        #expect(scene.version == VCamScene.currentVersion)
    }
}
