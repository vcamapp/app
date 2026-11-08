import Foundation
import VCamBridge
import VCamData

@MainActor
public enum MotionControl {
    /// Set by the renderer, which is what can read a motion. nil where motions have no known length
    public static var durationProvider: ((String) async -> Double?)?

    /// How long `waitUntilStopped` allows a motion to start. It loads before it plays
    private static let startTimeout = Duration.seconds(5)
    private static let pollInterval = Duration.milliseconds(30)

    public static func play(id: String, isLoop: Bool) {
        UniBridge.playMotion(id: id, isLoop: isLoop)
    }

    public static func stop(id: String) {
        UniBridge.stopMotion(id: id)
    }

    /// Plays the motion, or stops it if it is already playing
    public static func toggle(id: String, trigger: MotionPlaybackTrigger, library: MotionLibrary = .shared, state: UniState = .shared) {
        guard library.motionExists(id) else {
            return
        }
        if state.isMotionPlaying[id, default: false] {
            stop(id: id)
        } else {
            play(id: id, isLoop: library.isLoopEnabled(for: id, trigger: trigger))
        }
    }

    public static func duration(of id: String) async -> Double? {
        await durationProvider?(id)
    }

    /// Finishes when the motion has stopped, or when it never starts. The engine reports only
    /// playing or not, so this reads that state, which is what the app's own UI goes by.
    public static func waitUntilStopped(id: String, state: UniState = .shared) async {
        let clock = ContinuousClock()
        let deadline = clock.now + startTimeout
        while !state.isMotionPlaying[id, default: false] {
            guard clock.now < deadline, !Task.isCancelled else { return }
            try? await Task.sleep(for: pollInterval)
        }
        while state.isMotionPlaying[id, default: false], !Task.isCancelled {
            try? await Task.sleep(for: pollInterval)
        }
    }
}
