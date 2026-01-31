import Foundation

public struct LocalizationEnvironment {
    nonisolated(unsafe) public static var currentLocaleIdentifier: @Sendable () -> String = { "" }

    public static var language: Language {
        LanguageList(locale: currentLocaleIdentifier()).language
    }
}
