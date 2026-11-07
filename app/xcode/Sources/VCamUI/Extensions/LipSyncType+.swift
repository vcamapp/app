import Foundation
import VCamEntity

extension LipSyncType {
    func name(faceTrackingMethod: TrackingMethod.Face) -> String {
        switch self {
        case .mic:
            return String(localized: .mic)
        case .faceTracking:
            let source = faceTrackingMethod == .default ? String(localized: .camera) : faceTrackingMethod.name
            return String(localized: .lipSyncFaceTracking(source))
        }
    }
}
