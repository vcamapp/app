import Foundation

/// Opts out of App Nap while frames leave the app (virtual camera or recording).
///
/// Those outputs keep running while the window is hidden or covered by the app that reads the
/// virtual camera, which is exactly when App Nap throttles the frame loop (a 60 fps loop drops to
/// 12-27 fps with stalls over a second). Idle system sleep stays allowed.
@MainActor
final class FrameOutputActivity {
    static let shared = FrameOutputActivity()

    var isVirtualCameraStreaming = false {
        didSet { update() }
    }

    var isRecording = false {
        didSet { update() }
    }

    private var activity: (any NSObjectProtocol)?

    private init() {}

    private func update() {
        let isOutputting = isVirtualCameraStreaming || isRecording
        if isOutputting, activity == nil {
            activity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep, reason: "Sending frames")
        } else if !isOutputting, let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
    }
}
