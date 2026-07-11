import AppKit
import VCamEntity
import VCamBridge
import VCamData
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
        if UniState.shared.isMotionPlaying[.init(name: configuration.motion.rawValue), default: false] {
            UniBridge.stopMotion(name: configuration.motion.rawValue)
        } else {
            UniBridge.playMotion(name: configuration.motion.rawValue, isLoop: true)
        }
    }
}
