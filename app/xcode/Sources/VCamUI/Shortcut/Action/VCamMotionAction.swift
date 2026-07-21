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
        let motionID = configuration.motionID
        guard MotionLibrary.shared.motionExists(motionID) else {
            return // Safely ignore motions that have been deleted
        }
        if UniState.shared.isMotionPlaying[motionID, default: false] {
            UniBridge.stopMotion(id: motionID)
        } else {
            UniBridge.playMotion(id: motionID, isLoop: MotionLibrary.shared.isLoopEnabled(for: motionID, trigger: .shortcut))
        }
    }
}
