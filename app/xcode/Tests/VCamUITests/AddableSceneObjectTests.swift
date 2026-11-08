import Foundation
import Testing
@testable import VCamUI

@MainActor
@Suite
struct AddableSceneObjectTests {
    @Test(arguments: ["clip.mp4", "clip.MOV", "clip.m4v"])
    func aMovieFileIsAddedAsAVideo(name: String) {
        #expect(AddableSceneObject.isVideoFile(URL(filePath: "/tmp/\(name)")))
    }

    @Test(arguments: ["picture.png", "picture.jpg", "animation.gif", "no-extension"])
    func anythingElseIsAddedAsAnImage(name: String) {
        #expect(!AddableSceneObject.isVideoFile(URL(filePath: "/tmp/\(name)")))
    }
}
