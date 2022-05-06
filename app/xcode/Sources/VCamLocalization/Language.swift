//
//  Language.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/04/06.
//

import Foundation
import SwiftUI

public enum LanguageList: String, CaseIterable, Equatable, Identifiable {
    case `default` = "", japanese = "ja_JP", english = "en_US"

    public var id: Self { self }

    public init(locale: String) {
        self = LanguageList(rawValue: locale) ?? .default
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

    public var language: Language {
        switch self {
        case .default where Locale.current.identifier == LanguageList.japanese.rawValue,
                .japanese:
            return .japanese
        default:
            return .english
        }
    }
}

public enum Language: String {
    case japanese = "ja_JP", english = "en_US"

    public var languageCode: String {
        switch self {
        case .japanese:
            return "ja"
        case .english:
            return "en"
        }
    }

    public var locale: Locale {
        Locale(identifier: rawValue)
    }
}
