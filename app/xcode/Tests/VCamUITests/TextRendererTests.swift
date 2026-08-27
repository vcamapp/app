import Testing
import VCamEntity
@testable import VCamUI

@Suite
@MainActor
struct TextRendererTests {
    private let configuration = TextObjectConfiguration(text: "VCam", fontSize: 64)

    private func renderer(displayScale: Double, renderScale: Double) -> TextRenderer {
        TextRenderer(layout: .init(configuration: configuration, displayScale: displayScale, renderScale: renderScale))
    }

    @Test
    func renderScaleOnlyChangesTheBitmap() {
        let canvasSized = renderer(displayScale: 1, renderScale: 1)
        let outputSized = renderer(displayScale: 1, renderScale: 3)

        #expect(outputSized.textureSize.width > canvasSized.textureSize.width * 2.9)
        #expect(abs(outputSized.size.width - canvasSized.size.width) < 1)
        #expect(abs(outputSized.layoutSize.width - canvasSized.layoutSize.width) < 1)
    }

    @Test
    func aResolutionChangeRerasterizes() {
        let renderer = renderer(displayScale: 1, renderScale: 1)
        let canvasSize = renderer.size

        renderer.setScale(display: 1, render: 2)

        #expect(renderer.textureSize.width > canvasSize.width * 1.9)
        #expect(abs(renderer.size.width - canvasSize.width) < 1)
    }

    /// A scale that round-trips back with float noise must not rasterize again
    @Test
    func aSubPixelScaleChangeIsIgnored() {
        let renderer = renderer(displayScale: 2, renderScale: 1.5)
        let textureSize = renderer.textureSize

        renderer.setScale(display: 2.0001, render: 1.5)

        #expect(renderer.textureSize == textureSize)
    }

    @Test
    func anInvalidScaleIsIgnored() {
        let renderer = renderer(displayScale: 1, renderScale: 1)
        let textureSize = renderer.textureSize

        renderer.setScale(display: 2, render: 0)
        renderer.setScale(display: .nan, render: 2)

        #expect(renderer.textureSize == textureSize)
    }
}
