import SwiftUI
import Testing
@testable import VCamData

struct ColorHexTests {
    @Test(arguments: ["DEF3FFFF", "C6E7FFFF", "00FF0080", "12345678", "FFFFFF00"])
    func aHexStringWritesBackUnchanged(_ hex: String) throws {
        let color = try #require(Color(hexRGBA: hex))
        #expect(color.hexRGBAString == hex)
    }
}
