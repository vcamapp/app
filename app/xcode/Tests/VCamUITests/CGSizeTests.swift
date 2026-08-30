import CoreGraphics
import Testing
@testable import VCamUI

@Suite
struct CGSizeTests {
    @Test
    func scaleToFitUsesTheConstrainingAxis() {
        var wideContainer = CGSize(width: 100, height: 50)
        wideContainer.scaleToFit(size: CGSize(width: 400, height: 100))
        #expect(wideContainer == CGSize(width: 100, height: 25))

        var tallContainer = CGSize(width: 100, height: 50)
        tallContainer.scaleToFit(size: CGSize(width: 100, height: 400))
        #expect(tallContainer == CGSize(width: 12.5, height: 50))
    }

    @Test
    func scaleToFitKeepsInvalidDimensionsUnchanged() {
        var container = CGSize(width: 100, height: 50)
        container.scaleToFit(size: .zero)
        #expect(container == CGSize(width: 100, height: 50))
    }
}
