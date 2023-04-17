//
//  VCamShortcut+View.swift
//
//
//  Created by Tatsuya Tanaka on 2023/04/02.
//

import Foundation
import VCamEntity
import SwiftUI

public extension VCamShortcut {
    var icon: Image {
        if let iconName {
            return Image(systemName: iconName)
        }
        return configurations.first?.action().icon ?? Image(systemName: "star.fill")
    }
}

public extension View {
    @ViewBuilder func keyboardShortcut(_ shortcutKey: VCamShortcut.ShortcutKey?, action: @escaping () -> Void) -> some View {
        if let shortcutKey {
            // Workround to make shortcut keys work on any button
            let hiddenButton = Button("", action: action)
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)

            background {
                let key = KeyEquivalent(Character(shortcutKey.character))
                hiddenButton
                    .keyboardShortcut(key, modifiers: shortcutKey.eventModifiers)
            }

        } else {
            self
        }
    }
}

extension AnyVCamActionConfiguration {
    func action() -> any VCamAction {
        switch self {
        case .emoji(let configuration):
            return VCamEmojiAction(configuration: configuration)
        case .message(let configuration):
            return VCamMessageAction(configuration: configuration)
        case .motion(let configuration):
            return VCamMotionAction(configuration: configuration)
        case .blendShape(let configuration):
            return VCamBlendShapeAction(configuration: configuration)
        case .wait(let configuration):
            return VCamWaitAction(configuration: configuration)
        case .resetCamera(let configuration):
            return VCamResetCameraAction(configuration: configuration)
        case .loadScene(let configuration):
            return VCamLoadSceneAction(configuration: configuration)
        case .appleScript(let configuration):
            return VCamAppleScriptAction(configuration: configuration)
        }
    }
}

let allActions: [any VCamAction] = [
    VCamEmojiAction(configuration: .default),
    VCamMessageAction(configuration: .default),
    VCamMotionAction(configuration: .default),
    VCamBlendShapeAction(configuration: .default),
    VCamWaitAction(configuration: .default),
    VCamResetCameraAction(configuration: .default),
    VCamLoadSceneAction(configuration: .default),
    VCamAppleScriptAction(configuration: .default),
]
