import AppKit
import VCamEntity
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
        EmojiStamp.show?(try configuration.emoji.drawImage())
    }
}
