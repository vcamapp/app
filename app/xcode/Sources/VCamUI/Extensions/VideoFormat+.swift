import Foundation
import VCamEntity

extension VideoFormat {
    var localizedName: String {
        switch self {
        case .mp4:
            "mp4"
        case .mov:
            "mov"
        case .m4v:
            "m4v"
        case .hevcWithAlpha:
            String(localized: .videoFormatHEVC)
        }
    }
}
