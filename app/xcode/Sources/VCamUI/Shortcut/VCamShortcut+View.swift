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

extension AnyVCamActionConfiguration {
    func action() -> any VCamAction {
        switch self {
        case .emoji(let configuration):
            return VCamEmojiAction(configuration: configuration)
        case .message(let configuration):
            return VCamSubtitleAction(configuration: configuration)
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

@MainActor
let allActions: [any VCamAction] = [
    VCamEmojiAction(configuration: .default),
    VCamSubtitleAction(configuration: .default),
    VCamMotionAction(configuration: .default),
    VCamBlendShapeAction(configuration: .default),
    VCamWaitAction(configuration: .default),
    VCamResetCameraAction(configuration: .default),
    VCamLoadSceneAction(configuration: .default),
    VCamAppleScriptAction(configuration: .default),
]
