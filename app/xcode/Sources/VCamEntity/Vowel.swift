#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public enum Vowel: Int32, Equatable, CaseIterable, Sendable {
    case a, i, u, e, o
}
