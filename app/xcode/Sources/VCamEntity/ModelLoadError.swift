/// Why loading a model failed. The codes cross the bridge and are fixed identifiers;
/// which of them a build reports depends on what draws the avatar
public enum ModelLoadError: Int32, EngineResultError {
    /// The result never came back (app-side only)
    case timedOut = -1
    /// The load failed without a more specific reason. The engine falls back to the sample model
    case loadFailed = 1
    /// The request could not be accepted (e.g. during a scene transition);
    /// a retry can succeed once the scene settles
    case notReady = 2
    /// The file could not be read: moved, deleted, or not permitted
    case fileUnreadable = 3
    /// The file was read but is not a model that can be drawn
    case unsupportedModel = 4

    public static var unknown: Self { .loadFailed }
}
