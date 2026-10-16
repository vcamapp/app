import AppKit
import Carbon.HIToolbox
import Foundation
import Testing
@testable import VCamEntity

@Suite
struct KeyCombinationTests {
    @Test
    func requiresModifierForRegularKey() {
        #expect(!KeyCombination(key: "a", keyCode: UInt16(kVK_ANSI_A)).isEnabled)
        #expect(KeyCombination(key: "a", keyCode: UInt16(kVK_ANSI_A), modifiers: .control).isEnabled)
    }

    @Test
    func allowsStandaloneFunctionKeysUnusedByKeyboards() {
        #expect(KeyCombination(key: "\u{F710}", keyCode: UInt16(kVK_F13)).isEnabled)
        #expect(!KeyCombination(key: "\u{F704}", keyCode: UInt16(kVK_F1)).isEnabled)
    }

    @Test
    func describesFunctionKeysByName() {
        #expect(KeyCombination(key: "\u{F710}", keyCode: UInt16(kVK_F13)).description == "F13")
        #expect(KeyCombination(key: "\u{F704}", keyCode: UInt16(kVK_F1), modifiers: [.command, .shift]).description == "⌘ + ⇧ + F1")
        #expect(KeyCombination(key: "t", modifiers: .control).description == "⌃ + T")
    }

    @Test
    func detectsCommonAppShortcuts() {
        #expect(KeyCombination(key: "c", modifiers: .command).isCommonAppShortcut)
        #expect(KeyCombination(key: "z", modifiers: [.command, .shift]).isCommonAppShortcut)
        #expect(!KeyCombination(key: "c", modifiers: [.command, .option]).isCommonAppShortcut)
        #expect(!KeyCombination(key: "c", modifiers: .control).isCommonAppShortcut)
    }
}

@Suite
struct VCamShortcutKeyTests {
    @Test
    func decodeKeyWithoutKeyCode() throws {
        let json = """
        { "character": "a", "modifiers": 262144 }
        """
        let key = try JSONDecoder().decode(VCamShortcut.ShortcutKey.self, from: Data(json.utf8))
        #expect(key == .init(character: "a", keyCode: nil, modifiers: NSEvent.ModifierFlags.control.rawValue))
    }

    @Test
    func roundTripKeyCode() throws {
        let key = VCamShortcut.ShortcutKey(character: "\u{F710}", keyCode: UInt16(kVK_F13), modifiers: 0)
        let decoded = try JSONDecoder().decode(VCamShortcut.ShortcutKey.self, from: JSONEncoder().encode(key))
        #expect(decoded == key)
    }
}
