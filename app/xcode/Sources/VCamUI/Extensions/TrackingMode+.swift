import Foundation
import VCamBridge
import VCamTrackingCore

extension TrackingMode {
    var name: String {
        switch self {
        case .blendShape: String(localized: .normal)
        case .perfectSync: String(localized: .highPrecision)
        }
    }
}
