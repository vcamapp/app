//
//  VCamResetCameraAction.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/03.
//

import Foundation
import VCamEntity
import VCamBridge
import VCamLocalization
import struct SwiftUI.Image

public struct VCamResetCameraAction: VCamAction {
    public init(configuration: VCamResetCameraActionConfiguration) {
        self.configuration = configuration
    }

    public var configuration: VCamResetCameraActionConfiguration
    public var name: String { L10n.resetModelPosition.text }
    public var icon: Image { Image(systemName: "arrow.triangle.2.circlepath.camera.fill") }

    @MainActor
    public func callAsFunction(context: VCamActionContext) async throws {
        UniBridge.shared.resetCamera()
    }
}
