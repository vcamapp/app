//
//  QualityLevel+.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/08/13.
//

import Foundation
import VCamEntity
import VCamLocalization
import SwiftUI

public extension QualityLevel {
    var localizedName: LocalizedStringKey {
        switch self {
        case .fastest:
            return L10n.qualityFastest.key
        case .fast:
            return L10n.qualityFast.key
        case .simple:
            return L10n.qualitySimple.key
        case .good:
            return L10n.qualityGood.key
        case .beautiful:
            return L10n.qualityBeautiful.key
        case .fantastic:
            return L10n.qualityFantastic.key
        }
    }
}
