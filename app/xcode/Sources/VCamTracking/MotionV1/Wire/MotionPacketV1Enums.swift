public enum MotionPacketTypeV1: UInt8, Sendable {
    case face = 1
    case hands = 2
}

public enum HandTrackingStateV1: UInt8, Sendable {
    case missing = 0
    case tracked = 1
    case held = 2
}
