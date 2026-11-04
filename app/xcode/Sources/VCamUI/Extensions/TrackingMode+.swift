import Foundation
import VCamBridge
import VCamTrackingCore

extension TrackingMode {
    var name: String {
        switch self {
        case .perfectSync: String(localized: .trackingModeHighPrecisionStandard)
        case .blendShape: String(localized: .trackingModeLegacy)
        }
    }
}
