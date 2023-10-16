//
//  LensFlare.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/03/22.
//

import Foundation
import VCamLocalization

public enum LensFlare: Int32, CaseIterable, Identifiable, CustomStringConvertible {
    case none, type1, type2, type3, type4

    public var id: Self { self }

    public static func initOrNone(_ value: Int32) -> Self {
        .init(rawValue: value) ?? .none
    }

    public var description: String {
        switch self {
        case .none:
            return L10n.none.text
        case .type1:
            return L10n.typeNo("1").text
        case .type2:
            return L10n.typeNo("2").text
        case .type3:
            return L10n.typeNo("3").text
        case .type4:
            return L10n.typeNo("4").text
        }
    }
}
