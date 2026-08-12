import VCamBridge
import VCamData

/// Motion playback operations shared by the toolbar, shortcuts, and other entry points
@MainActor
public enum MotionControl {
    public static func play(id: String, isLoop: Bool) {
        UniBridge.playMotion(id: id, isLoop: isLoop)
    }

    public static func stop(id: String) {
        UniBridge.stopMotion(id: id)
    }

    /// Plays the motion, or stops it if it is already playing
    public static func toggle(id: String, trigger: MotionPlaybackTrigger, library: MotionLibrary = .shared, state: UniState = .shared) {
        guard library.motionExists(id) else {
            return // Safely ignore motions that have been deleted
        }
        if state.isMotionPlaying[id, default: false] {
            stop(id: id)
        } else {
            play(id: id, isLoop: library.isLoopEnabled(for: id, trigger: trigger))
        }
    }
}
