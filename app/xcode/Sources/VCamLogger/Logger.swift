import Foundation

public struct Logger: Sendable {
    nonisolated(unsafe) private static var _error: (@Sendable (any Error) -> Void) = { print($0) }
    nonisolated(unsafe) private static var _logInternal: (@Sendable (String, StaticString, StaticString, Int) -> Void) = { print($0, $1, $2, $3) }
    nonisolated(unsafe) private static var _logEventInternal: (@Sendable (Event) -> Void) = { print($0) }

    public static var error: (@Sendable (any Error) -> Void) {
        get { _error }
        set { _error = newValue }
    }

    public static func log(_ message: String, file: StaticString = #file, function: StaticString = #function, line: Int = #line) {
        let handler = _logInternal
        Task(priority: .background) { @MainActor in
            handler(message, file, function, line)
        }
    }

    public static var logInternal: (@Sendable (String, StaticString, StaticString, Int) -> Void) {
        get { _logInternal }
        set { _logInternal = newValue }
    }
}

public extension Logger {
    enum Event: String, Sendable {
        case installPlugin = "install_plugin"
        case openVRoidHub = "open_vroidhub"
        case loadVRMFile = "load_vrmfile"
        case loadModelFile = "load_modelfile"
    }

    static func log(event: Event) {
        let handler = _logEventInternal
        Task(priority: .background) { @MainActor in
            handler(event)
        }
    }

    static var logEventInternal: (@Sendable (Event) -> Void) {
        get { _logEventInternal }
        set { _logEventInternal = newValue }
    }
}
