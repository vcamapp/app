import Foundation
import simd

enum MotionPacketV1Decoder {
    enum Error: Swift.Error {
        case truncated, invalidHeader, invalidSize
    }

    static func headerIfV1(_ data: Data) throws -> MotionPacketHeaderV1? {
        guard data.count >= MotionPacketV1Constants.headerSize else { throw Error.truncated }
        return try data.withUnsafeBytes { raw -> MotionPacketHeaderV1? in
            let reader = Reader(raw)
            guard reader.u32(MotionPacketV1Layout.Header.magic) == MotionPacketV1Constants.magic else { return nil }
            guard reader.u16(MotionPacketV1Layout.Header.version) == MotionPacketV1Constants.version,
                  let type = MotionPacketTypeV1(rawValue: reader.u8(MotionPacketV1Layout.Header.packetType)) else {
                throw Error.invalidHeader
            }

            let size = Int(reader.u32(MotionPacketV1Layout.Header.packetByteCount))
            guard size == data.count, size >= MotionPacketV1Constants.headerSize else {
                throw Error.invalidSize
            }
            return MotionPacketHeaderV1(
                type: type,
                sessionID: reader.u32(MotionPacketV1Layout.Header.sessionID),
                sequence: reader.u32(MotionPacketV1Layout.Header.sequence)
            )
        }
    }

    static func validateHandsPacket(_ data: Data, header: MotionPacketHeaderV1) throws {
        guard header.type == .hands, data.count == MotionPacketV1Constants.handsPacketSize else { throw Error.invalidSize }
    }

    static func decodeFace(_ data: Data, header: MotionPacketHeaderV1) throws -> VCamMotion {
        guard header.type == .face, data.count == MotionPacketV1Constants.facePacketSize else {
            throw Error.invalidSize
        }
        return try data.withUnsafeBytes { raw -> VCamMotion in
            let reader = Reader(raw)
            let face = MotionPacketV1Layout.Face.self
            let translation = SIMD3(reader.f32(face.translation), reader.f32(face.translation + 4), reader.f32(face.translation + 8))
            let rotation = reader.quaternion(face.rotation)
            let lookAt = SIMD2(reader.f32(face.lookAtPoint), reader.f32(face.lookAtPoint + 4))
            guard finite(translation), finite(lookAt), finite(rotation.vector),
                  simd_length_squared(rotation.vector) > 0.00000001 else { throw Error.invalidHeader }
            var blend = BlendShape(lookAtPoint: lookAt)
            for (index, keyPath) in BlendShape.wireOrder.enumerated() {
                let value = reader.f32(face.blendShapes + index * 4)
                guard value.isFinite else { throw Error.invalidHeader }
                blend[keyPath: keyPath] = min(max(value, 0), 1)
            }
            return VCamMotion(
                version: 1,
                head: .init(
                    translation: translation,
                    rotation: simd_normalize(rotation)
                ),
                hands: .init(right: .missing, left: .missing),
                blendShape: blend
            )
        }
    }

    private static func finite(_ value: SIMD2<Float>) -> Bool { value[0].isFinite && value[1].isFinite }
    private static func finite(_ value: SIMD3<Float>) -> Bool { value[0].isFinite && value[1].isFinite && value[2].isFinite }
    private static func finite(_ value: SIMD4<Float>) -> Bool { value[0].isFinite && value[1].isFinite && value[2].isFinite && value[3].isFinite }
}

private struct Reader {
    let bytes: UnsafeRawBufferPointer

    init(_ bytes: UnsafeRawBufferPointer) {
        self.bytes = bytes
    }

    func u8(_ offset: Int) -> UInt8 {
        bytes[offset]
    }

    func u16(_ offset: Int) -> UInt16 {
        bytes.loadUnaligned(fromByteOffset: offset, as: UInt16.self).littleEndian
    }

    func u32(_ offset: Int) -> UInt32 {
        bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self).littleEndian
    }

    func f32(_ offset: Int) -> Float {
        Float(bitPattern: u32(offset))
    }

    func quaternion(_ offset: Int) -> simd_quatf {
        .init(ix: f32(offset), iy: f32(offset + 4), iz: f32(offset + 8), r: f32(offset + 12))
    }
}
