import Foundation

extension Float {
    /// Parses user-typed text tolerantly: accepts both "." and "," as the decimal
    /// separator (the last one wins) and ignores any other stray characters.
    init?(userInput text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let characters = Array(trimmed)
        var lastSeparatorIndex: Int?
        for (index, character) in characters.enumerated() {
            if character == "." || character == "," {
                lastSeparatorIndex = index
            }
        }

        var normalized = ""
        normalized.reserveCapacity(characters.count)
        for (index, character) in characters.enumerated() {
            if character.isWholeNumber || character == "-" || character == "+" {
                normalized.append(character)
                continue
            }
            if (character == "." || character == ",") && index == lastSeparatorIndex {
                normalized.append(".")
            }
        }

        self.init(normalized)
    }
}
