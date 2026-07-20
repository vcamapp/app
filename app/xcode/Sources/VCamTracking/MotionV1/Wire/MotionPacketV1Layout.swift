// VCamMocap also uses tha same source file for its decoder, 
// so the layout definitions are shared between the two.
public enum MotionPacketV1Layout {
    public enum Header {
        public static let magic = 0
        public static let version = 4
        public static let packetType = 6
        public static let flags = 7
        public static let packetByteCount = 8
        public static let sessionID = 12
        public static let sequence = 16
        public static let reserved = 20
        public static let timestampNanoseconds = 24
    }

    public enum Face {
        public static let translation = 32
        public static let rotation = 44
        public static let lookAtPoint = 60
        public static let blendShapes = 68
        public static let blendShapeCount = 52
    }

    public enum Hands {
        public static let left = 32
        public static let right = 316

        public enum Hand {
            public static let state = 0
            public static let wristPosition = 4
            public static let wristRotation = 16
            public static let normalizedJoints = 32
        }
    }
}
