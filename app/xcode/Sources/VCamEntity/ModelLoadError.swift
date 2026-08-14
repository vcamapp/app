/// Model load errors (the positive codes mirror the engine-side ModelLoadError)
public enum ModelLoadError: Int32, Error, Sendable {
    /// The engine never reported a result (app-side only)
    case timedOut = -1
    /// The load failed and the engine fell back to the sample model
    case loadFailed = 1
    /// The engine could not accept the request (e.g. during a scene transition);
    /// a retry can succeed once the scene settles
    case notReady = 2

    public init(code: Int32) {
        self = Self(rawValue: code) ?? .loadFailed
    }
}
