import Foundation
import Testing
@testable import VCamUI

@Suite
struct KeyboardLayoutTests {
    @Test
    func resolvesCharactersOnPlainAndShiftedLayers() {
        #expect(KeyboardLayout.keyCode(for: "a") != nil)
        #expect(KeyboardLayout.keyCode(for: "A") == KeyboardLayout.keyCode(for: "a"))
        #expect(KeyboardLayout.keyCode(for: " ") != nil)
        #expect(KeyboardLayout.keyCode(for: "!") != nil)
    }

    @Test
    func doesNotResolveFunctionKeyCharacters() {
        #expect(KeyboardLayout.keyCode(for: "\u{F710}") == nil)
    }
}
