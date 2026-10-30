import SIMDCompat

/// The latest values a VMC Protocol performer has sent, folded from its messages. A bone keeps its last value
/// until `reset()`: a performer may split a frame over datagrams, and each datagram only refreshes what it carries
package struct VMCPerformerState: Sendable {
    package typealias Transform = VMCPerformerFrame.Transform

    package struct Update: Sendable {
        /// The root or a bone changed
        package var movesBody = false
        /// `/VMC/Ext/Blend/Apply` arrived
        package var appliesExpressions = false
    }

    private var root: Transform?
    private var bones = [Transform?](repeating: nil, count: VMCBone.allCases.count)
    private var pendingExpressions: [String: Float] = [:]
    package private(set) var expressions: [String: Float]?

    package init() {}

    package mutating func reset() {
        self = VMCPerformerState()
    }

    package mutating func receive(_ messages: [OSCMessage]) -> Update {
        var update = Update()
        for message in messages {
            switch message.address {
            case "/VMC/Ext/Root/Pos":
                guard let transform = Self.transform(in: message) else { continue }
                root = Self.aligned(transform, to: root)
                update.movesBody = true
            case "/VMC/Ext/Bone/Pos":
                guard let name = message.string(at: 0), let index = Self.boneIndices[name],
                      let transform = Self.transform(in: message) else { continue }
                bones[index] = Self.aligned(transform, to: bones[index])
                update.movesBody = true
            case "/VMC/Ext/Blend/Val":
                guard let name = message.string(at: 0), let value = message.float(at: 1) else { continue }
                pendingExpressions[name] = value
            case "/VMC/Ext/Blend/Apply":
                expressions = pendingExpressions
                pendingExpressions.removeAll(keepingCapacity: true)
                update.appliesExpressions = true
            default:
                continue
            }
        }
        return update
    }

    // MARK: - Resampling

    /// The root, then each `VMCBone` in order, as position xyz and rotation xyzw
    package static let resamplerValueCount = (1 + VMCBone.allCases.count) * 7

    /// For `TrackingResampler`. What has not arrived yet is NaN, which stays NaN through the interpolation
    package var resamplerValues: [Float] {
        var values: [Float] = []
        values.reserveCapacity(Self.resamplerValueCount)
        for transform in [root] + bones {
            if let transform {
                let rotation = transform.rotation.vector
                values += [transform.position.x, transform.position.y, transform.position.z,
                           rotation.x, rotation.y, rotation.z, rotation.w]
            } else {
                values += [Float](repeating: .nan, count: 7)
            }
        }
        return values
    }

    package static func frame(fromResamplerValues values: [Float], expressions: [String: Float]?) -> VMCPerformerFrame {
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
        return VMCPerformerFrame(root: transform(at: 0), bones: bones, expressions: expressions)
    }

    // MARK: - Messages

    private static let boneIndices = Dictionary(uniqueKeysWithValues: VMCBone.allCases.enumerated().map { ($1.rawValue, $0) })

    /// `s fff ffff`. Extra arguments after the rotation (the scale and offset of the root) are ignored
    private static func transform(in message: OSCMessage) -> Transform? {
        let floats = (1...7).compactMap { message.float(at: $0) }
        guard floats.count == 7, floats.allSatisfy(\.isFinite) else { return nil }
        let rotation = simd_quatf(ix: floats[3], iy: floats[4], iz: floats[5], r: floats[6])
        guard simd_length(rotation.vector) > 0.0001 else { return nil }
        return Transform(position: SIMD3(floats[0], floats[1], floats[2]), rotation: simd_normalize(rotation))
    }

    /// The resampler interpolates the quaternion componentwise, so each one stays on the side of the previous one
    private static func aligned(_ transform: Transform, to previous: Transform?) -> Transform {
        guard let previous, simd_dot(previous.rotation.vector, transform.rotation.vector) < 0 else { return transform }
        return Transform(position: transform.position, rotation: simd_quatf(vector: -transform.rotation.vector))
    }
}
