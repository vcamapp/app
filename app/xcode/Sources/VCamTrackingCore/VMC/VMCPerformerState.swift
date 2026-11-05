#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SIMDCompat

/// The latest values a VMC Protocol performer has sent, folded from its packets. A bone keeps its last value:
/// a performer may split a frame over datagrams, and each datagram only refreshes what it carries
package struct VMCPerformerState: Sendable {
    package typealias Transform = VMCPerformerFrame.Transform

    package struct Update: Sendable {
        /// The root or a bone changed
        package var movesBody = false
        /// `/VMC/Ext/Blend/Apply` arrived
        package var appliesExpressions = false

        package init() {}

        package var isEmpty: Bool { !movesBody && !appliesExpressions }

        package mutating func merge(_ other: Update) {
            movesBody = movesBody || other.movesBody
            appliesExpressions = appliesExpressions || other.appliesExpressions
        }
    }

    /// For `TrackingResampler`: the root, then each `VMCBone` in order, as position xyz and rotation xyzw.
    /// What has not arrived yet is NaN, which stays NaN through the interpolation
    package private(set) var resamplerValues = [Float](repeating: .nan, count: Self.resamplerValueCount)
    private var pendingExpressions: [String: Float] = [:]
    package private(set) var expressions: [String: Float]?
    /// The weight names in the order of the last frame, reused while the performer keeps sending them in that order
    private var expressionNames: [String] = []
    /// The weights read since the last `/VMC/Ext/Blend/Apply`
    private var expressionCount = 0

    package init() {}

    package mutating func receive(_ packet: Data) -> Update {
        var update = Update()
        packet.withUnsafeBytes { bytes in
            OSCPacketReader.forEachMessage(in: bytes) { message in
                receive(message, into: &update)
            }
        }
        return update
    }

    private mutating func receive(_ message: OSCMessageView, into update: inout Update) {
        var arguments = message.arguments
        if message.hasAddress("/VMC/Ext/Bone/Pos") {
            guard case .string(let name)? = arguments.next(), let index = BoneNames.index(of: name),
                  receiveTransform(from: &arguments, at: index + 1) else { return }
            update.movesBody = true
        } else if message.hasAddress("/VMC/Ext/Blend/Val") {
            guard case .string(let name)? = arguments.next(), let value = arguments.next()?.number else { return }
            pendingExpressions[expressionName(name)] = value
        } else if message.hasAddress("/VMC/Ext/Root/Pos") {
            // The root's name is not used
            _ = arguments.next()
            guard receiveTransform(from: &arguments, at: 0) else { return }
            update.movesBody = true
        } else if message.hasAddress("/VMC/Ext/Blend/Apply") {
            expressions = pendingExpressions
            pendingExpressions.removeAll(keepingCapacity: true)
            expressionCount = 0
            update.appliesExpressions = true
        }
    }

    /// `fff ffff`. Extra arguments after the rotation (the scale and offset of the root) are ignored
    private mutating func receiveTransform(from arguments: inout OSCArguments, at slot: Int) -> Bool {
        var floats = SIMD8<Float>()
        for index in 0..<7 {
            guard let value = arguments.next()?.number, value.isFinite else { return false }
            floats[index] = value
        }
        let rotation = simd_quatf(ix: floats[3], iy: floats[4], iz: floats[5], r: floats[6])
        guard simd_length(rotation.vector) > 0.0001 else { return false }
        var vector = simd_normalize(rotation).vector
        let base = slot * 7
        let previous = SIMD4(resamplerValues[base + 3], resamplerValues[base + 4],
                             resamplerValues[base + 5], resamplerValues[base + 6])
        // The resampler interpolates the quaternion componentwise, so each one stays on the side of the previous one.
        // A slot that has not arrived yet is NaN, which never compares below zero
        if simd_dot(previous, vector) < 0 {
            vector = -vector
        }
        for index in 0..<3 {
            resamplerValues[base + index] = floats[index]
        }
        for index in 0..<4 {
            resamplerValues[base + 3 + index] = vector[index]
        }
        return true
    }

    /// Performers send the same names in the same order every frame, so a name is made only when it changes
    private mutating func expressionName(_ bytes: UnsafeRawBufferPointer) -> String {
        defer { expressionCount += 1 }
        if expressionCount < expressionNames.count {
            if expressionNames[expressionCount].utf8.elementsEqual(bytes) {
                return expressionNames[expressionCount]
            }
            let name = String(decoding: bytes, as: UTF8.self)
            expressionNames[expressionCount] = name
            return name
        }
        let name = String(decoding: bytes, as: UTF8.self)
        // A performer that never applies would otherwise grow this without bound
        if expressionNames.count < Self.maximumExpressionNameCount {
            expressionNames.append(name)
        }
        return name
    }

    private static let maximumExpressionNameCount = 256

    // MARK: - Resampling

    package static let resamplerValueCount = (1 + VMCBone.allCases.count) * 7

    package static func frame(fromResamplerValues values: [Float]) -> VMCPerformerFrame {
        precondition(values.count == resamplerValueCount, "VMC resampler values size mismatch")
        func transform(at slot: Int) -> Transform? {
            let base = slot * 7
            let position = SIMD3(values[base], values[base + 1], values[base + 2])
            let rotation = SIMD4(values[base + 3], values[base + 4], values[base + 5], values[base + 6])
            let length = simd_length(rotation)
            guard !position.x.isNaN, length.isFinite, length > 0.0001 else { return nil }
            return Transform(position: position, rotation: simd_quatf(vector: rotation / length))
        }
        var bones: [VMCBone: Transform] = [:]
        for (index, bone) in VMCBone.allCases.enumerated() {
            bones[bone] = transform(at: index + 1)
        }
        return VMCPerformerFrame(root: transform(at: 0), bones: bones)
    }
}

/// Finds a bone by the bytes of its name, without making a String
private enum BoneNames {
    private static let names = VMCBone.allCases.map { Array($0.rawValue.utf8) }
    private static let indices = Dictionary(
        uniqueKeysWithValues: names.enumerated().map { ($1.withUnsafeBytes(BoneNames.hash), $0) }
    )

    static func index(of name: UnsafeRawBufferPointer) -> Int? {
        guard let index = indices[hash(name)], names[index].elementsEqual(name) else { return nil }
        return index
    }

    /// FNV-1a
    private static func hash(_ bytes: UnsafeRawBufferPointer) -> UInt64 {
        bytes.reduce(0xcbf2_9ce4_8422_2325) { ($0 ^ UInt64($1)) &* 0x100_0000_01b3 }
    }
}
