//
//  Language.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/04/06.
//

import Foundation

public enum Language: String, CaseIterable, Equatable, Identifiable {
    case `default` = "", japanese = "ja_JP", english = "en_US"

    public var id: Self { self }

    public init(locale: String) {
        self = Language(rawValue: locale) ?? .default
    }

    public var name: String {
        switch self {
        case .default:
            return L10n.languageOfDevice.text
        case .japanese:
            return L10n.japanese.text
        case .english:
            return L10n.english.text
        }
    }

    public var languageCode: String {
        switch self {
        case .default where Locale.current.identifier == Language.japanese.rawValue,
                .japanese:
            return "ja"
        default:
            return "en"
        }
    }
}
