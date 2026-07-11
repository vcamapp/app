import SwiftUI
import VCamEntity

extension VCamAvatarMotion: CustomStringConvertible {
    public var description: String {
        switch self {
        case .hi:
            return String(localized: .hi)
        case .bye:
            return String(localized: .bye)
        case .jump:
            return String(localized: .jump)
        case .cheer:
            return String(localized: .cheer)
        case .what:
            return String(localized: .what)
        case .pose:
            return String(localized: .pose)
        case .nod:
            return String(localized: .nod)
        case .no:
            return String(localized: .no)
        case .shudder:
            return String(localized: .shudder)
        case .run:
            return String(localized: .run)
        }
    }
}
