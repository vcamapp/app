import Foundation
import VCamEntity
import SwiftUI

public extension QualityLevel {
    var localizedName: LocalizedStringResource {
        switch self {
        case .fastest:
            return .qualityFastest
        case .fast:
            return .qualityFast
        case .simple:
            return .qualitySimple
        case .good:
            return .qualityGood
        case .beautiful:
            return .qualityBeautiful
        case .fantastic:
            return .qualityFantastic
        }
    }
}
