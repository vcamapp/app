//
//  KeyCombination+Shortcut.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/16.
//

import AppKit
import Carbon.HIToolbox
import VCamEntity

extension VCamShortcut.ShortcutKey {
    init(_ keyCombination: KeyCombination) {
        self.init(character: keyCombination.key, keyCode: keyCombination.keyCode, modifiers: keyCombination.modifiers.rawValue)
    }

    var keyCombination: KeyCombination {
        .init(key: character, keyCode: resolvedKeyCode, modifiers: .init(rawValue: modifiers))
    }

    var resolvedKeyCode: UInt16? {
        keyCode ?? KeyboardLayout.keyCode(for: character)
    }
}

enum KeyboardLayout {
    /// The recorded character already reflects Shift, so both the plain and shifted layers are searched
    static func keyCode(for character: String) -> UInt16? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let data = Unmanaged<CFData>.fromOpaque(layoutData).takeUnretainedValue() as Data
        let target = character.lowercased()
        let modifierKeyStates = [0, UInt32(shiftKey >> 8) & 0xFF]

        return data.withUnsafeBytes { buffer -> UInt16? in
            guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
            for modifierKeyState in modifierKeyStates {
                for keyCode in UInt16(0)..<128 {
                    var deadKeyState: UInt32 = 0
                    var characters = [UniChar](repeating: 0, count: 4)
                    var length = 0
                    let status = UCKeyTranslate(
                        layout,
                        keyCode,
                        UInt16(kUCKeyActionDisplay),
                        modifierKeyState,
                        UInt32(LMGetKbdType()),
                        OptionBits(kUCKeyTranslateNoDeadKeysBit),
                        &deadKeyState,
                        characters.count,
                        &length,
                        &characters
                    )
                    if status == noErr, length > 0, String(utf16CodeUnits: characters, count: length).lowercased() == target {
                        return keyCode
                    }
                }
            }
            return nil
        }
    }
}
