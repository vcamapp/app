//
//  VCamShortcut+View.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/02.
//

import Foundation
import VCamEntity
import struct SwiftUI.Image

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
        case .motion(let configuration):
            return VCamMotionAction(configuration: configuration)
        case .blendShape(configuration: let configuration):
            return VCamBlendShapeAction(configuration: configuration)
        case .wait(configuration: let configuration):
            return VCamWaitAction(configuration: configuration)
        case .resetCamera(configuration: let configuration):
            return VCamResetCameraAction(configuration: configuration)
        case .loadScene(configuration: let configuration):
            return VCamLoadSceneAction(configuration: configuration)
        }
    }
}

let allActions: [any VCamAction] = [
    VCamEmojiAction(configuration: .default),
    VCamMotionAction(configuration: .default),
    VCamBlendShapeAction(configuration: .default),
    VCamWaitAction(configuration: .default),
    VCamResetCameraAction(configuration: .default),
    VCamLoadSceneAction(configuration: .default),
]
