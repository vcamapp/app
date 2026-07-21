import Foundation
import VCamEntity

public extension Avatar.Motion {
    var localizedDisplayName: String {
        if case .builtIn(let name) = MotionID(rawValue: id),
           let motion = VCamAvatarMotion(rawValue: name) {
            return motion.description
        }
        return displayName
    }
}

public extension VrmaMotionError {
    var localizedMessage: String {
        switch self {
        case .unsupportedAvatar:
            String(localized: .vrmaRequiresVRM1Message)
        default:
            String(localized: .failedToLoadMotion)
        }
    }
}
