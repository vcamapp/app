import CoreGraphics
import Testing
import VCamEntity
@testable import VCamUI

@MainActor
@Suite
struct RenderTextureManagerTests {
    private let id: Int32 = 1
    private let placement = CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.1)

    /// A text shown on screen through a manager of its own
    private func shownText(_ text: String) async -> (RenderTextureManager, TextRenderer) {
        let manager = RenderTextureManager()
        let renderer = TextRenderer(layout: layout(text))
        manager.set(renderer, id: id)
        manager.allocateTexture(id: id, width: Int(renderer.textureSize.width), height: Int(renderer.textureSize.height))
        await manager.waitForStaticTextures(timeout: .seconds(5))
        return (manager, renderer)
    }

    private func layout(_ text: String, fill: TextObjectConfiguration.Fill = .solid(.white)) -> TextRenderer.Layout {
        .init(configuration: .init(text: text, fontSize: 64, fill: fill), displayScale: 1, renderScale: 1)
    }

    @Test
    func aResizedTextKeepsItsPlacementUntilTheNewTextureIsWritten() async throws {
        let (manager, renderer) = await shownText("VCam")

        renderer.layout = layout("VCam API demo")
        manager.holdPlacement(placement, id: id)
        #expect(manager.heldPlacement(id: id) == placement)

        for _ in 0..<500 where manager.heldPlacement(id: id) != nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(manager.heldPlacement(id: id) == nil)
        #expect(manager.texture(id: id)?.width == Int(renderer.textureSize.width))
    }

    /// A subtitle restyled to another size keeps something on screen until the new pixels exist
    @Test
    func aResizedTextShowsTheOldTextureUntilTheNewOneIsWritten() async throws {
        let (manager, renderer) = await shownText("VCam")
        let shown = try #require(manager.texture(id: id))

        renderer.layout = layout("VCam API demo")
        #expect(manager.texture(id: id) === shown)

        for _ in 0..<500 where manager.texture(id: id) === shown {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(manager.texture(id: id)?.width == Int(renderer.textureSize.width))
    }

    /// A same-sized texture is written in place, so the new content is on screen at once
    @Test
    func aSameSizedChangeHoldsNothing() async {
        let (manager, renderer) = await shownText("VCam")

        renderer.layout = layout("VCam", fill: .solid(.black))
        manager.holdPlacement(placement, id: id)

        #expect(manager.heldPlacement(id: id) == nil)
    }

    @Test
    func removingTheTextureDropsTheHold() async {
        let (manager, renderer) = await shownText("VCam")

        renderer.layout = layout("VCam API demo")
        manager.holdPlacement(placement, id: id)
        manager.remove(id: id)

        #expect(manager.heldPlacement(id: id) == nil)
    }
}
