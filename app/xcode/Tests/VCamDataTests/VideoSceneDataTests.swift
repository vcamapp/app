import Foundation
import Testing
import VCamData
import VCamEntity

@Suite
struct VideoSceneDataTests {
    private func makeStore() -> VCamSceneDataStore {
        VCamSceneDataStore(sceneId: .random(in: 1_000_000..<Int32.max))
    }

    private func makeSourceFile(named name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: name)
        try Data("data".utf8).write(to: url)
        return url
    }

    @Test
    func aVideoKeepsItsExtensionThroughCopies() throws {
        let store = makeStore()
        defer { try? store.delete() }

        let copied = try store.copyDataKeepingExtension(fromURL: makeSourceFile(named: "clip.mov"))
        let duplicated = try store.duplicateData(at: copied)

        #expect(copied.pathExtension == "mov")
        #expect(duplicated.pathExtension == "mov")
        #expect(duplicated != copied)
        #expect(FileManager.default.fileExists(atPath: duplicated.path(percentEncoded: false)))
    }

    @Test
    func anImageStaysWithoutAnExtensionWhenDuplicated() throws {
        let store = makeStore()
        defer { try? store.delete() }

        let copied = try store.copyData(fromURL: makeSourceFile(named: "picture.png"))
        let duplicated = try store.duplicateData(at: copied)

        #expect(copied.pathExtension.isEmpty)
        #expect(duplicated.pathExtension.isEmpty)
    }

    @Test
    func aVideoObjectRoundTripsThroughTheSceneFile() throws {
        let plane = VCamScene.Plane(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
        let object = VCamScene.Object(id: 3, name: "Clip", type: .video(id: "ABC.mp4", state: .init(
            texture: .init(width: 640, height: 360, region: plane, crop: .init(x: 0, y: 0, width: 1, height: 1), filter: nil),
            isLooping: false,
            isMuted: true
        )), isHidden: false, isLocked: false)

        let decoded = try JSONDecoder().decode(VCamScene.Object.self, from: JSONEncoder().encode(object))

        guard case let .video(id, state) = decoded.type else {
            Issue.record("Unexpected type: \(decoded.type)")
            return
        }
        #expect(id == "ABC.mp4")
        #expect(state.isLooping == false)
        #expect(state.isMuted == true)
        #expect(state.texture.width == 640)
    }

    @Test
    func aVideoObjectKeepsItsFileNameAndOptionsWhenLoaded() throws {
        let store = makeStore()
        let plane = VCamScene.Plane(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
        let object = VCamScene.Object(id: 3, name: "Clip", type: .video(id: "ABC.mp4", state: .init(
            texture: .init(width: 640, height: 360, region: plane, crop: .init(x: 0, y: 0, width: 1, height: 1), filter: nil),
            isLooping: false,
            isMuted: true
        )), isHidden: false, isLocked: false)

        let sceneObject = object.sceneObject(dataStore: store)

        guard case let .video(video) = sceneObject.type else {
            Issue.record("Unexpected type: \(sceneObject.type)")
            return
        }
        #expect(video.url == store.dataURL(id: "ABC.mp4"))
        #expect(video.isLooping == false)
        #expect(video.textureSize == CGSize(width: 640, height: 360))
    }
}
