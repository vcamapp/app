import AppKit
import VCamEntity
import VCamBridge
import struct SwiftUI.Image

public struct VCamEmojiAction: VCamAction {
    public init(configuration: VCamEmojiActionConfiguration) {
        self.configuration = configuration
    }

    public var configuration: VCamEmojiActionConfiguration
    public var name: String { String(localized: .emoji) }
    public var icon: Image { Image(systemName: "smiley") }

    @MainActor
    public func callAsFunction(context: VCamActionContext) async throws {
        guard !configuration.emoji.isEmpty else {
            throw VCamActionError(String(localized: .isNotSetYet(String(localized: .emoji))))
        }
        let url = URL.temporaryDirectory.appending(path: "vcam_emoji.png")
        try configuration.emoji.drawImage().writeAsPNG(to: url)

        UniBridge.shared.showEmojiStamp(url.path)
    }
}
