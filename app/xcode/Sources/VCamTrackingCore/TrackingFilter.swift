import Foundation

public enum TrackingFilter: Codable, Sendable, Hashable {
    case none
    /// - Parameters:
    ///   - minCutoff: Normalized value (0-1).
    ///   - beta: Normalized value (0-1).
    case oneEuro(minCutoff: Float, beta: Float)

    public static let defaultOneEuro = TrackingFilter.oneEuro(minCutoff: 0.81632656, beta: 0.25)

    public var typeId: Int32 {
        switch self {
        case .none: 0
        case .oneEuro: 1
        }
    }

    public var parameters: [Float] {
        switch self {
        case .none:
            []
        case .oneEuro(let minCutoff, let beta):
            [minCutoff, beta]
        }
    }
}
