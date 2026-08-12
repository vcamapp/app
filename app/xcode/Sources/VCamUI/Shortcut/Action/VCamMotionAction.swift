import AppKit
import VCamEntity
import VCamControl
import SwiftUI

public struct VCamMotionAction: VCamAction {
    public init(configuration: VCamMotionActionConfiguration) {
        self.configuration = configuration
    }

    public var configuration: VCamMotionActionConfiguration
    public var name: String { String(localized: .motion) }
    public var icon: Image { Image(systemName: "figure.wave") }

    @MainActor
    public func callAsFunction(context: VCamActionContext) async throws {
        MotionControl.toggle(id: configuration.motionID, trigger: .shortcut)
    }
}
