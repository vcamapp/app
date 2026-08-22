import Foundation
import VCamEntity

public extension AccessoryApplyError {
    /// The engine reports only a code, so the message is spelled out here.
    var localizedMessage: String {
        switch self {
        case .timedOut:
            String(localized: .accessoryApplyTimedOut)
        case .notReady:
            String(localized: .avatarNotLoaded)
        case .applyFailed:
            String(localized: .accessoryApplyFailed)
        }
    }
}
