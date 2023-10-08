//
//  VCamMotionAction.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/01.
//

import AppKit
import VCamEntity
import VCamLocalization
import VCamBridge
import struct SwiftUI.Image

public struct VCamMotionAction: VCamAction {
    public init(configuration: VCamMotionActionConfiguration) {
        self.configuration = configuration
    }

    public var configuration: VCamMotionActionConfiguration
    public var name: String { L10n.motion.text }
    public var icon: Image { Image(systemName: "figure.wave") }

    @MainActor
    public func callAsFunction(context: VCamActionContext) async throws {
        switch configuration.motion {
        case .hi:
            UniBridge.shared.motionHello()
        case .bye:
            UniBridge.shared.motionBye.wrappedValue.toggle()
        case .jump:
            UniBridge.shared.motionJump()
        case .cheer:
            UniBridge.shared.motionYear()
        case .what:
            UniBridge.shared.motionWhat()
        case .pose:
            UniBridge.shared.motionWin()
        case .nod:
            UniBridge.shared.motionNod.wrappedValue.toggle()
        case .no:
            UniBridge.shared.motionShakeHead.wrappedValue.toggle()
        case .shudder:
            UniBridge.shared.motionShakeBody.wrappedValue.toggle()
        case .run:
            UniBridge.shared.motionRun.wrappedValue.toggle()
        }
    }
}
