import AppKit
import VCamEntity
import VCamBridge
import struct SwiftUI.Image

public struct VCamBlendShapeAction: VCamAction {
    public init(configuration: VCamBlendShapeActionConfiguration) {
        self.configuration = configuration
    }

    public var configuration: VCamBlendShapeActionConfiguration
    public var name: String { String(localized: .facialExpression) }
    public var icon: Image { Image(systemName: "face.smiling") }

    @MainActor
    public func callAsFunction(context: VCamActionContext) async throws {
        guard !configuration.blendShape.isEmpty else {
            throw VCamActionError(String(localized: .isNotSetYet(String(localized: .facialExpression))))
        }

        UniBridge.applyExpression(name: configuration.blendShape)
    }
}
