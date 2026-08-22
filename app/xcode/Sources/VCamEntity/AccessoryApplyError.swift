/// Errors from applying accessory placements to the engine (codes shared with the engine side)
public enum AccessoryApplyError: Int32, EngineResultError {
    /// The engine never reported a result (app-side only)
    case timedOut = -1
    /// Loading or placing an accessory failed
    case applyFailed = 1
    /// The engine could not accept the request (e.g. no avatar is loaded yet)
    case notReady = 2

    public static var unknown: Self { .applyFailed }
}
