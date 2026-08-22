/// An error the engine reports as an Int32 code, so that anything awaiting an
/// engine result can map a code without knowing the concrete error type
public protocol EngineResultError: RawRepresentable<Int32>, Error, Sendable {
    /// Stands in for a code this build does not know
    static var unknown: Self { get }
}

public extension EngineResultError {
    init(code: Int32) {
        self = Self(rawValue: code) ?? .unknown
    }
}
