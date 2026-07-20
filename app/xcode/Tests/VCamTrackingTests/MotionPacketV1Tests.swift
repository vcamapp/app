import Foundation
import Testing
@testable import VCamTracking

@Suite
struct MotionPacketV1Tests {
    @Test
    func validatesFixedHandPacketSize() throws {
        var data = Data(repeating: 0, count: MotionPacketV1Constants.handsPacketSize)
        let byteCount = UInt32(data.count)
        data.withUnsafeMutableBytes { bytes in
            bytes.storeBytes(of: UInt32(0x314D4356).littleEndian, toByteOffset: 0, as: UInt32.self)
            bytes.storeBytes(of: UInt16(1).littleEndian, toByteOffset: 4, as: UInt16.self)
            bytes.storeBytes(of: UInt8(2), toByteOffset: 6, as: UInt8.self)
            bytes.storeBytes(of: byteCount.littleEndian, toByteOffset: 8, as: UInt32.self)
            bytes.storeBytes(of: UInt32(0x11223344).littleEndian, toByteOffset: 12, as: UInt32.self)
            bytes.storeBytes(of: UInt32(7).littleEndian, toByteOffset: 16, as: UInt32.self)
            bytes.storeBytes(of: UInt64(123456789).littleEndian, toByteOffset: 24, as: UInt64.self)
        }

        let header = try #require(try MotionPacketV1Decoder.headerIfV1(data))
        #expect(header.type == .hands)
        #expect(header.sessionID == 0x11223344)
        #expect(header.sequence == 7)
        try MotionPacketV1Decoder.validateHandsPacket(data, header: header)
        #expect(throws: MotionPacketV1Decoder.Error.self) {
            let truncated = Data(data.dropLast())
            if let header = try MotionPacketV1Decoder.headerIfV1(truncated) {
                try MotionPacketV1Decoder.validateHandsPacket(truncated, header: header)
            }
        }
    }

    @Test
    func sequenceStateRejectsOldPacketsAndResetsForNewSession() {
        var state = MotionSequenceState()
        #expect(state.canAccept(sessionID: 10, sequence: 100))
        state.commit(sessionID: 10, sequence: 100)
        #expect(!state.canAccept(sessionID: 10, sequence: 99))
        #expect(state.canAccept(sessionID: 10, sequence: 101))
        state.commit(sessionID: 10, sequence: UInt32.max)
        #expect(state.canAccept(sessionID: 10, sequence: 0))
        #expect(!state.canAccept(sessionID: 11, sequence: 0))
        state.reset()
        #expect(state.canAccept(sessionID: 11, sequence: 0))
    }

    @Test
    func faceDecoderRejectsNonFiniteAndZeroQuaternion() throws {
        var data = Data(repeating: 0, count: MotionPacketV1Constants.facePacketSize)
        let byteCount = UInt32(data.count).littleEndian
        data.withUnsafeMutableBytes { bytes in
            bytes.storeBytes(of: UInt32(MotionPacketV1Constants.magic).littleEndian, toByteOffset: 0, as: UInt32.self)
            bytes.storeBytes(of: UInt16(MotionPacketV1Constants.version).littleEndian, toByteOffset: 4, as: UInt16.self)
            bytes.storeBytes(of: UInt8(MotionPacketTypeV1.face.rawValue), toByteOffset: 6, as: UInt8.self)
            bytes.storeBytes(of: byteCount, toByteOffset: 8, as: UInt32.self)
        }
        let header = try #require(try MotionPacketV1Decoder.headerIfV1(data))
        #expect(throws: MotionPacketV1Decoder.Error.self) {
            try MotionPacketV1Decoder.decodeFace(data, header: header)
        }

        data.withUnsafeMutableBytes { bytes in
            bytes.storeBytes(of: Float.nan.bitPattern.littleEndian, toByteOffset: MotionPacketV1Layout.Face.translation, as: UInt32.self)
            bytes.storeBytes(of: Float(1).bitPattern.littleEndian, toByteOffset: MotionPacketV1Layout.Face.rotation + 12, as: UInt32.self)
        }
        #expect(throws: MotionPacketV1Decoder.Error.self) {
            try MotionPacketV1Decoder.decodeFace(data, header: header)
        }
    }
}
