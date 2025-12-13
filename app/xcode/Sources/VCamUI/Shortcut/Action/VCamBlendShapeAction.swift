//
//  VCamBlendShapeAction.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/02.
//

import AppKit
import VCamEntity
import VCamBridge
import VCamLocalization
import struct SwiftUI.Image

public struct VCamBlendShapeAction: VCamAction {
    public init(configuration: VCamBlendShapeActionConfiguration) {
        self.configuration = configuration
    }

    public var configuration: VCamBlendShapeActionConfiguration
    public var name: String { L10n.facialExpression.text }
    public var icon: Image { Image(systemName: "face.smiling") }

    @MainActor
    public func callAsFunction(context: VCamActionContext) async throws {
        guard !configuration.blendShape.isEmpty else {
            throw VCamActionError(L10n.isNotSetYet(L10n.facialExpression.text).text)
        }

        UniBridge.applyExpression(name: configuration.blendShape)
    }
}
