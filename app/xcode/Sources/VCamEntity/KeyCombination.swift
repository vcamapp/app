#if canImport(AppKit)
import Foundation
import class AppKit.NSEvent
import Carbon.HIToolbox.Events

public struct KeyCombination: Equatable, CustomStringConvertible, Sendable {
    public init(key: String = "", keyCode: UInt16? = nil, modifiers: NSEvent.ModifierFlags = []) {
        self.key = key.lowercased()
        self.keyCode = keyCode
        self.modifiers = Modifier.filter(modifiers)
    }

    public let key: String
    public let keyCode: UInt16?
    public let modifiers: NSEvent.ModifierFlags

    public static let empty = KeyCombination()

    public var description: String {
        (Modifier.allCases
            .filter { !modifiers.intersection($0.flag).isEmpty }
            .map(\.keySymbol) + [readableKeyName])
            .joined(separator: " + ")
    }

    public var readableKeyName: String {
        if let keyCode, let name = Self.specialKeyNames[Int(keyCode)] {
            return name
        }
        return key == " " ? "Space" : key.uppercased()
    }

    public var isEnabled: Bool {
        guard !key.isEmpty else { return false }
        return Modifier.hasModifiers(modifiers) || keyCode.map { Self.standaloneKeyCodes.contains(Int($0)) } == true
    }

    /// Hotkeys take the key away from every other app, so a key alone is only allowed when no keyboard
    /// or app uses it for anything else; Stream Deck and similar devices can still send these keys
    public static let standaloneKeyCodes: Set<Int> = [
        kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
    ]

    /// Most apps assign ⌘ and ⌘⇧ combinations to their menu items
    public var isCommonAppShortcut: Bool {
        modifiers == .command || modifiers == [.command, .shift]
    }

    // These keys produce private-use or control characters that can't be displayed as they are
    private static let specialKeyNames: [Int: String] = [
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
        kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
        kVK_F11: "F11", kVK_F12: "F12", kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15",
        kVK_F16: "F16", kVK_F17: "F17", kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20",
        kVK_Space: "Space", kVK_Return: "↩", kVK_ANSI_KeypadEnter: "⌤", kVK_Tab: "⇥",
        kVK_Escape: "⎋", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
    ]

    public enum Modifier: CaseIterable, Identifiable {
        case command, shift, control, option

        public static let supportedModifiers: NSEvent.ModifierFlags = [.command, .shift, .control, .option]

        public static func hasModifiers(_ flags: NSEvent.ModifierFlags) -> Bool {
            !flags.intersection(supportedModifiers).isEmpty
        }

        public static func filter(_ flags: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
            flags.intersection(supportedModifiers)
        }

        public var id: Self {
            self
        }

        public var flag: NSEvent.ModifierFlags {
            switch self {
            case .command: return .command
            case .shift: return .shift
            case .control: return .control
            case .option: return .option
            }
        }

        public var keySymbol: String {
            switch self {
            case .command: return "⌘"
            case .shift: return "⇧"
            case .control: return "⌃"
            case .option: return "⌥"
            }
        }
    }
}
#endif
