import AppKit
import VCamEntity
import VCamBridge
import VCamData
import struct SwiftUI.Image

public struct VCamMessageAction: VCamAction {
    public init(configuration: VCamMessageActionConfiguration) {
        self.configuration = configuration
    }

    public var configuration: VCamMessageActionConfiguration
    public var name: String { String(localized: .message) }
    public var icon: Image { Image(systemName: "text.bubble") }

    @MainActor
    public func callAsFunction(context: VCamActionContext) async throws {
        UniState.shared.message = configuration.message
    }
}
