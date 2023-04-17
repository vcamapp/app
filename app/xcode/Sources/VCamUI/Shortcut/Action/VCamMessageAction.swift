//
//  VCamMessageAction.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/16.
//

import AppKit
import VCamEntity
import VCamLocalization
import struct SwiftUI.Image

public struct VCamMessageAction: VCamAction {
    public init(configuration: VCamMessageActionConfiguration) {
        self.configuration = configuration
    }

    public var configuration: VCamMessageActionConfiguration
    public var name: String { L10n.message.text }
    public var icon: Image { Image(systemName: "text.bubble") }

    @UniState(.message) private var message

    @MainActor
    public func callAsFunction(context: VCamActionContext) async throws {
        message = configuration.message
    }
}
