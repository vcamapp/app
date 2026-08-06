import Foundation
import simd

struct MotionPacketWriter {
    let bytes: UnsafeMutableRawBufferPointer

    func u8(_ value: UInt8, at offset: Int) { bytes[offset] = value }
    func u16(_ value: UInt16, at offset: Int) { store(value.littleEndian, at: offset) }
    func u32(_ value: UInt32, at offset: Int) { store(value.littleEndian, at: offset) }
    func u64(_ value: UInt64, at offset: Int) { store(value.littleEndian, at: offset) }
    func float(_ value: Float, at offset: Int) { u32(value.bitPattern, at: offset) }

    func vector2(_ value: SIMD2<Float>, at offset: Int) {
        float(value.x, at: offset)
        float(value.y, at: offset + 4)
    }

    func vector3(_ value: SIMD3<Float>, at offset: Int) {
        float(value.x, at: offset)
        float(value.y, at: offset + 4)
        float(value.z, at: offset + 8)
    }

    func quaternion(_ value: simd_quatf, at offset: Int) {
        let q = simd_normalize(value)
        float(q.vector.x, at: offset)
        float(q.vector.y, at: offset + 4)
        float(q.vector.z, at: offset + 8)
        float(q.vector.w, at: offset + 12)
    }

    func header(type: MotionPacketTypeV1, size: Int, sessionID: UInt32, sequence: UInt32, timestamp: UInt64) {
        let header = MotionPacketV1Layout.Header.self
        u32(MotionPacketV1Constants.magic, at: header.magic)
        u16(MotionPacketV1Constants.version, at: header.version)
        u8(type.rawValue, at: header.packetType)
        u8(0, at: header.flags)
        u32(UInt32(size), at: header.packetByteCount)
        u32(sessionID, at: header.sessionID)
        u32(sequence, at: header.sequence)
        u32(0, at: header.reserved)
        u64(timestamp, at: header.timestampNanoseconds)
    }

    private func store<T>(_ value: T, at offset: Int) {
        bytes.baseAddress!.storeBytes(of: value, toByteOffset: offset, as: T.self)
    }
}
