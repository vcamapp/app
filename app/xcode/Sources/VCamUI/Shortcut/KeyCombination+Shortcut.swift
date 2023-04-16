//
//  KeyCombination+Shortcut.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/16.
//

import SwiftUI
import VCamEntity

extension VCamShortcut.ShortcutKey {
    var eventModifiers: EventModifiers {
        let modifierFlags = NSEvent.ModifierFlags(rawValue: modifiers)

        var result = EventModifiers()
        if modifierFlags.contains(.command) {
            result.insert(.command)
        }
        if modifierFlags.contains(.shift) {
            result.insert(.shift)
        }
        if modifierFlags.contains(.control) {
            result.insert(.control)
        }
        if modifierFlags.contains(.option) {
            result.insert(.option)
        }

#if DEBUG
        // Prevent forgetting to implement
        for modifier in KeyCombination.Modifier.allCases {
            switch modifier {
            case .command, .shift, .control, .option: ()
            }
        }
#endif

        return result
    }
}
