//
//  KeyCombination.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/15.
//

import Foundation
import class AppKit.NSEvent
import var Carbon.HIToolbox.Events.kVK_Space

public struct KeyCombination: Equatable {
    public init(key: String = "", keyCode: UInt16 = 0, modifiers: NSEvent.ModifierFlags = []) {
        self.key = key
        self.keyCode = keyCode
        self.modifiers = Modifier.filter(modifiers)
    }

    public var key = ""
    public var keyCode: UInt16 = 0
    public var modifiers: NSEvent.ModifierFlags = []

    public static let empty = KeyCombination()

    public var keyName: String {
        switch keyCode {
        case UInt16(kVK_Space):
            return "Space"
        default:
            return key.uppercased()
        }
    }

    public var isEnabled: Bool {
        !key.isEmpty && Modifier.hasModifiers(modifiers)
    }

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
