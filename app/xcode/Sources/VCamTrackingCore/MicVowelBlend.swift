import Foundation
import VCamEntity

/// Cross-fades the mouth between vowel shapes. An estimated vowel changes in a single step, which would look like a flicker.
public struct MicVowelBlend {
    private static let followTime = 0.06

    /// Indexed by `Vowel.rawValue`, and always sums to 1
    private var weights: [Float] = Self.initialWeights

    private static let initialWeights: [Float] = Vowel.allCases.map { $0 == .a ? 1 : 0 }

    public init() {}

    public mutating func reset() {
        weights = Self.initialWeights
    }

    public mutating func update(toward vowel: Vowel, deltaTime: TimeInterval) {
        let rate = Float(1 - exp(-deltaTime / Self.followTime))
        for candidate in Vowel.allCases {
            let index = Int(candidate.rawValue)
            let target: Float = candidate == vowel ? 1 : 0
            weights[index] += (target - weights[index]) * rate
        }
    }

    public func weight(of vowel: Vowel) -> Float {
        weights[Int(vowel.rawValue)]
    }
}
