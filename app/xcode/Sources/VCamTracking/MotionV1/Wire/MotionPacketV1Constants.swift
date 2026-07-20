// Keep these values synchronized with VCamMocap and MotionPacketV1Layout.
public enum MotionPacketV1Constants {
    public static let magic: UInt32 = 0x314D4356
    public static let version: UInt16 = 1
    public static let headerSize = 32
    public static let facePacketSize = 276
    public static let handsPacketSize = 600
    public static let handSize = 284
    public static let normalizedJointCount = 21

    /// Bonjour TXT record key advertising the receiver's supported protocol
    /// versions as a comma-separated list (e.g. "0,1").
    public static let motionProtocolsTXTRecordKey = "motionProtocols"
    public static let motionV1ProtocolID = 1
}
