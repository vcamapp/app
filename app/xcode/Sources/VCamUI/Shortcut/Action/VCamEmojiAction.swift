//
//  VCamEmojiAction.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/03/24.
//

import AppKit
import VCamEntity
import VCamBridge
import VCamLocalization
import struct SwiftUI.Image

public struct VCamEmojiAction: VCamAction {
    public init(configuration: VCamEmojiActionConfiguration) {
        self.configuration = configuration
    }

    public var configuration: VCamEmojiActionConfiguration
    public var name: String { L10n.emoji.text }
    public var icon: Image { Image(systemName: "smiley") }

    @MainActor
    public func callAsFunction(context: VCamActionContext) async throws {
        guard !configuration.emoji.isEmpty else {
            throw VCamActionError(L10n.isNotSetYet(L10n.emoji.text).text)
        }
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("vcam_emoji.png")
        try configuration.emoji.drawImage().writeAsPNG(to: url)

        UniBridge.shared.showEmojiStamp(url.path)
    }
}
