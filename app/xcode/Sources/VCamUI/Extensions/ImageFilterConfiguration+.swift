//
//  ImageFilterConfiguration+.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/06/18.
//

import Foundation
import VCamEntity

extension ImageFilterConfiguration.FilterType: Identifiable {
    public var id: String { name }

    public var name: String {
        switch self {
        case .chromaKey:
            return L10n.chromaKeying.text
        }
    }
}
