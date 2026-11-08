import Foundation

public enum RecordingControlError: Error {
    /// The user has to choose the folder in the app, since a remote request must not open a dialog
    case noFolder
}

/// Video recording behind an injected provider: the recorder lives in the UI layer,
/// which registers its implementation at startup.
@MainActor
public enum RecordingControl {
    public enum State: Equatable, Sendable {
        case idle
        case recording(startedAt: Date)
        /// A stopped recording is still being written to its file
        case finishing
    }

    /// nil until the UI layer has registered its implementation
    public static var provider: (any RecordingControlling)?
}

@MainActor
public protocol RecordingControlling: AnyObject {
    var state: RecordingControl.State { get }
    /// Records with the settings chosen in the app. Finishes when the recording has started
    func start() async throws
    /// Finishes when the video has been written to its file
    func stop() async
}
