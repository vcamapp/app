//
//  VCamMotionAction.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/01.
//

import AppKit
import VCamEntity
import VCamLocalization
import struct SwiftUI.Image

public struct VCamMotionAction: VCamAction {
    public init(configuration: VCamMotionActionConfiguration) {
        self.configuration = configuration
    }

    public var configuration: VCamMotionActionConfiguration
    public var name: String { L10n.motion.text }
    public var icon: Image { Image(systemName: "figure.wave") }

    @UniAction(.triggerMotion) var triggerMotion

    @MainActor
    public func callAsFunction(context: VCamActionContext) async throws {
        triggerMotion(configuration.motion)
    }
}
