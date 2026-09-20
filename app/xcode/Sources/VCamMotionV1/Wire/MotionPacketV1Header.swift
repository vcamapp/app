public struct MotionPacketHeaderV1: Sendable {
    public let type: MotionPacketTypeV1
    public let sessionID: UInt32
    public let sequence: UInt32
    public let timestampNanoseconds: UInt64

    public init(
        type: MotionPacketTypeV1,
        sessionID: UInt32,
        sequence: UInt32,
        timestampNanoseconds: UInt64
    ) {
        self.type = type
        self.sessionID = sessionID
        self.sequence = sequence
        self.timestampNanoseconds = timestampNanoseconds
    }
}
