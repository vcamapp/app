import Foundation

public struct TranslationAxisMask: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let x = Self(rawValue: 1 << 0)
    public static let y = Self(rawValue: 1 << 1)
    public static let z = Self(rawValue: 1 << 2)
    public static let all: Self = [.x, .y, .z]
}
