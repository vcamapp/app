import Foundation
import VCamData

/// The secret that clients on other devices present as `Authorization: Bearer <token>`.
/// It lives in UserDefaults rather than the keychain: anything that can read this Mac's
/// settings can already reach the API through 127.0.0.1 without it.
package enum ExternalControlToken {
    /// Returns the saved token, creating one when there is none yet
    @discardableResult
    package static func saved() -> String {
        let token = UserDefaults.standard.value(for: .integrationExternalControlToken)
        guard token.isEmpty else { return token }
        return regenerate()
    }

    @discardableResult
    package static func regenerate() -> String {
        let token = generate()
        UserDefaults.standard.set(token, for: .integrationExternalControlToken)
        return token
    }

    static func generate() -> String {
        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<32).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Compares in constant time so the response time does not reveal how much of a guess matched
    static func authorizes(_ headers: [(name: String, value: String)], token: String) -> Bool {
        let expected = Array("Bearer \(token)".utf8)
        return headers.contains { header in
            guard header.name.caseInsensitiveCompare("authorization") == .orderedSame else { return false }
            let actual = Array(header.value.utf8)
            guard actual.count == expected.count else { return false }
            return zip(actual, expected).reduce(0) { $0 | ($1.0 ^ $1.1) } == 0
        }
    }
}
