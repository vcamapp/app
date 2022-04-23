//
//  LocalizationEnvironment.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/04/18.
//

import Foundation

public struct LocalizationEnvironment {
    public static var currentLocale: () -> String = { "" }

    public static var language: Language {
        LanguageList(locale: currentLocale()).language
    }
}
