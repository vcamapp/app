import Foundation
import simd
import Testing
import VCamMotionV1

@Suite
struct MotionPacketV1EncoderTests {
    @available(macOS 26.0, *)
    @Test
    func faceEncoderWritesTheFixedBlendShapeOrder() {
        #expect(BlendShape.wireOrder.count == MotionPacketV1Layout.Face.blendShapeCount)
        var blendShape = BlendShape(lookAtPoint: SIMD2(4, 5))
        blendShape[keyPath: BlendShape.wireOrder[0]] = 0.125
        blendShape[keyPath: BlendShape.wireOrder[21]] = 0.375
        blendShape[keyPath: BlendShape.wireOrder[51]] = 0.875
        let motion = VCamMotion(
            version: 0,
            head: .init(
                translation: SIMD3(1, 2, 3),
                rotation: simd_quatf(vector: SIMD4(0, 0, 0, 1))
            ),
            hands: .init(right: .missing, left: .missing),
            blendShape: blendShape
        )

        let packet = MotionPacketV1Encoder.encodeFace(
            motion,
            sequence: 7,
            timestampNanoseconds: 9,
            sessionID: 11
        )

        #expect(packet.count == MotionPacketV1Constants.facePacketSize)
        #expect(packet.load(Float.self, at: MotionPacketV1Layout.Face.blendShapes) == 0.125)
        #expect(packet.load(Float.self, at: MotionPacketV1Layout.Face.blendShapes + 21 * 4) == 0.375)
        #expect(packet.load(Float.self, at: MotionPacketV1Layout.Face.blendShapes + 51 * 4) == 0.875)
    }

    @available(macOS 26.0, *)
    @Test
    func handsEncoderWritesTheFixedLayoutAndClearsMissingHands() {
        var joints = InlineArray<21, SIMD3<Float>>(repeating: .zero)
        joints[0] = SIMD3(1, 2, 3)
        joints[20] = SIMD3(4, 5, 6)
        let tracked = HandPoseV1(
            state: .tracked,
            wristPosition: SIMD3(7, 8, 9),
            wristRotation: simd_quatf(vector: SIMD4(0.1, 0.2, 0.3, 0.9)),
            normalizedJoints: joints
        )
        let ignoredMissingPayload = HandPoseV1(
            state: .missing,
            wristPosition: SIMD3(repeating: 10),
            wristRotation: simd_quatf(vector: SIMD4(repeating: 10)),
            normalizedJoints: InlineArray<21, SIMD3<Float>>(repeating: SIMD3(repeating: 10))
        )

        let packet = MotionPacketV1Encoder.encodeHands(
            .init(left: tracked, right: ignoredMissingPayload),
            sequence: 7,
            timestampNanoseconds: 11_000_000,
            sessionID: 13
        )
        let left = MotionPacketV1Layout.Hands.left
        let right = MotionPacketV1Layout.Hands.right
        let hand = MotionPacketV1Layout.Hands.Hand.self

        #expect(packet.count == MotionPacketV1Constants.handsPacketSize)
        #expect(packet.load(UInt32.self, at: MotionPacketV1Layout.Header.magic) == MotionPacketV1Constants.magic)
        #expect(packet.load(UInt32.self, at: MotionPacketV1Layout.Header.packetByteCount) == UInt32(MotionPacketV1Constants.handsPacketSize))
        #expect(packet.load(UInt32.self, at: MotionPacketV1Layout.Header.sessionID) == 13)
        #expect(packet.load(UInt32.self, at: MotionPacketV1Layout.Header.sequence) == 7)
        #expect(packet.load(UInt64.self, at: MotionPacketV1Layout.Header.timestampNanoseconds) == 11_000_000)
        #expect(packet.load(UInt8.self, at: left + hand.state) == HandTrackingStateV1.tracked.rawValue)
        #expect(packet.load(Float.self, at: left + hand.wristPosition + 8) == 9)
        #expect(packet.load(Float.self, at: left + hand.normalizedJoints) == 1)
        #expect(packet.load(Float.self, at: left + hand.normalizedJoints + 20 * 12 + 8) == 6)
        #expect(packet.load(UInt8.self, at: right + hand.state) == HandTrackingStateV1.missing.rawValue)
        #expect(packet.load(Float.self, at: right + hand.wristPosition) == 0)
        #expect(packet.load(Float.self, at: right + hand.wristRotation + 12) == 1)
        #expect(packet.load(Float.self, at: right + hand.normalizedJoints) == 0)
    }
}

private extension Data {
    func load<T>(_ type: T.Type, at offset: Int) -> T {
        withUnsafeBytes { raw in
            raw.loadUnaligned(fromByteOffset: offset, as: T.self)
        }
    }
}
