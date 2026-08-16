import Testing
import CoreGraphics
@testable import VCamUI

@Suite
@MainActor
struct TextObjectPlacementTests {
    private let canvasSize = CGSize(width: 1920, height: 1080)
    private let layoutSize = CGSize(width: 400, height: 200)

    @Test
    func scaleRejectsInvalidDimensions() {
        #expect(TextObjectPlacement.scale(
            region: .init(x: 0, y: 0, width: 0, height: 0.2),
            layoutSize: layoutSize,
            canvasSize: canvasSize
        ) == nil)
        #expect(TextObjectPlacement.scale(
            region: .init(x: 0, y: 0, width: 0.2, height: 0.2),
            layoutSize: .zero,
            canvasSize: canvasSize
        ) == nil)
        #expect(TextObjectPlacement.scale(
            region: .init(x: 0, y: 0, width: .infinity, height: 0.2),
            layoutSize: layoutSize,
            canvasSize: canvasSize
        ) == nil)
    }

    @Test
    func scaleFitsWithoutStretching() {
        let scale = TextObjectPlacement.scale(
            region: .init(x: 0, y: 0, width: 0.5, height: 0.5),
            layoutSize: layoutSize,
            canvasSize: canvasSize
        )

        #expect(scale == 2.4)
    }
}
