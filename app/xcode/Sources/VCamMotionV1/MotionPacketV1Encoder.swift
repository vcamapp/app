import Foundation

@available(iOS 26.0, macOS 26.0, *)
public enum MotionPacketV1Encoder {
    public static func encodeFace(_ motion: VCamMotion, sequence: UInt32, timestampNanoseconds: UInt64, sessionID: UInt32 = 0) -> Data {
        var data = Data(repeating: 0, count: MotionPacketV1Constants.facePacketSize)
        data.withUnsafeMutableBytes { raw in
            let writer = MotionPacketWriter(bytes: raw)
            let face = MotionPacketV1Layout.Face.self
            let blendShape = motion.blendShape
            writer.header(type: .face, size: MotionPacketV1Constants.facePacketSize, sessionID: sessionID, sequence: sequence, timestamp: timestampNanoseconds)
            writer.vector3(motion.head.translation, at: face.translation)
            writer.quaternion(motion.head.rotation, at: face.rotation)
            writer.vector2(blendShape.lookAtPoint, at: face.lookAtPoint)
            for index in 0..<face.blendShapeCount {
                writer.float(blendShape[keyPath: BlendShape.wireOrder[index]], at: face.blendShapes + index * 4)
            }
        }
        return data
    }

    public static func encodeHands(_ hands: HandsPoseV1, sequence: UInt32, timestampNanoseconds: UInt64, sessionID: UInt32 = 0) -> Data {
        var data = Data(repeating: 0, count: MotionPacketV1Constants.handsPacketSize)
        data.withUnsafeMutableBytes { raw in
            let writer = MotionPacketWriter(bytes: raw)
            writer.header(type: .hands, size: MotionPacketV1Constants.handsPacketSize, sessionID: sessionID, sequence: sequence, timestamp: timestampNanoseconds)
            write(hands.left, at: MotionPacketV1Layout.Hands.left, writer: writer)
            write(hands.right, at: MotionPacketV1Layout.Hands.right, writer: writer)
        }
        return data
    }

    private static func write(_ hand: HandPoseV1, at base: Int, writer: MotionPacketWriter) {
        writer.u8(hand.state.rawValue, at: base + MotionPacketV1Layout.Hands.Hand.state)
        guard hand.state != .missing else {
            writer.float(1, at: base + MotionPacketV1Layout.Hands.Hand.wristRotation + 12)
            return
        }
        writer.vector3(hand.wristPosition, at: base + MotionPacketV1Layout.Hands.Hand.wristPosition)
        writer.quaternion(hand.wristRotation, at: base + MotionPacketV1Layout.Hands.Hand.wristRotation)
        for index in 0..<MotionPacketV1Constants.normalizedJointCount {
            writer.vector3(hand.normalizedJoints[index], at: base + MotionPacketV1Layout.Hands.Hand.normalizedJoints + index * 12)
        }
    }
}
