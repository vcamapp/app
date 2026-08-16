import AppKit
import VCamEntity
import VCamBridge
import VCamData
import struct SwiftUI.Image

public struct VCamSubtitleAction: VCamAction {
    public init(configuration: VCamSubtitleActionConfiguration) {
        self.configuration = configuration
    }

    public var configuration: VCamSubtitleActionConfiguration
    public var name: String { String(localized: .subtitle) }
    public var icon: Image { Image(systemName: "text.bubble") }

    @MainActor
    public func callAsFunction(context: VCamActionContext) async throws {
        UniState.shared.subtitle = configuration.text
    }
}
