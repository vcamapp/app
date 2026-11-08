import VCamBridge

@MainActor
public enum GazeControl {
    public enum Target: Sendable {
        /// Face tracking, or looking ahead without it
        case auto
        case camera
        /// Degrees from straight ahead. Positive yaw looks to the right of the screen, positive pitch up
        case direction(yaw: Float, pitch: Float)
    }

    public static func look(at target: Target, movesHead: Bool) {
        switch target {
        case .auto:
            UniBridge.setGaze(mode: .auto, yaw: 0, pitch: 0, movesHead: movesHead)
        case .camera:
            UniBridge.setGaze(mode: .camera, yaw: 0, pitch: 0, movesHead: movesHead)
        case let .direction(yaw, pitch):
            UniBridge.setGaze(mode: .direction, yaw: yaw, pitch: pitch, movesHead: movesHead)
        }
    }
}
