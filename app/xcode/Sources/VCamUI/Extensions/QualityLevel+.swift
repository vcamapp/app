import Foundation
import VCamEntity
import SwiftUI

public extension QualityLevel {
    var localizedName: LocalizedStringResource {
        switch self {
        case .fastest:
            return .qualityVeryLow
        case .fast:
            return .qualityLow
        case .simple:
            return .qualityMedium
        case .good:
            return .qualityHigh
        case .beautiful:
            return .qualityVeryHigh
        case .fantastic:
            return .qualityUltra
        }
    }
}
