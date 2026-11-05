import Foundation
import simd
import Testing
@testable import VCamTrackingCore

@Suite
struct VMCProtocolTests {
    private static let identity = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)

    @Test
    func readsTheMessagesOfNestedBundles() {
        let bone = TestOSC.message("/VMC/Ext/Bone/Pos", .string("Hips"), .float(0), .float(0.9), .float(0),
                                   .float(0), .float(0), .float(0), .float(1))
        let blend = TestOSC.message("/VMC/Ext/Blend/Val", .string("Joy"), .float(0.5))
        let packet = TestOSC.bundle([bone, TestOSC.bundle([blend]), TestOSC.message("/VMC/Ext/Blend/Apply")])

        let messages = OSCPacketReader.messages(in: packet)

        #expect(messages.map(\.address) == ["/VMC/Ext/Bone/Pos", "/VMC/Ext/Blend/Val", "/VMC/Ext/Blend/Apply"])
        #expect(messages[0].arguments.first == .string("Hips"))
        #expect(messages[0].arguments[2] == .float(0.9))
        #expect(messages[1] == OSCMessage(address: "/VMC/Ext/Blend/Val", arguments: [.string("Joy"), .float(0.5)]))
        #expect(messages[2].arguments.isEmpty)
    }

    @Test
    func keepsTheMessagesBeforeABrokenOne() {
        var broken = TestOSC.message("/VMC/Ext/Blend/Val", .string("Joy"), .float(0.5))
        broken.removeLast(2)
        let packet = TestOSC.bundle([TestOSC.message("/VMC/Ext/Blend/Apply"), broken])

        #expect(OSCPacketReader.messages(in: packet).map(\.address) == ["/VMC/Ext/Blend/Apply"])
        #expect(OSCPacketReader.messages(in: Data([1, 2, 3])).isEmpty)
    }

    @Test
    func skipsAMalformedMessageButReadsTheNextElementOfItsBundle() {
        var unknownType = TestOSC.string("/VMC/Ext/Blend/Val") + TestOSC.string(",sXf")
        unknownType += TestOSC.string("Joy") + TestOSC.int32(Float(1).bitPattern)
        let packet = TestOSC.bundle([unknownType, TestOSC.message("/VMC/Ext/Blend/Apply")])

        #expect(OSCPacketReader.messages(in: packet).map(\.address) == ["/VMC/Ext/Blend/Apply"])
    }

    @Test
    func skipsTheArgumentsOfTypesItDoesNotUse() {
        var message = TestOSC.string("/VMC/Ext/Root/Pos") + TestOSC.string(",shfT")
        message += TestOSC.string("root") + Data(repeating: 0, count: 8) + TestOSC.int32(Float(2).bitPattern)

        let messages = OSCPacketReader.messages(in: message)

        #expect(messages.first?.arguments == [.string("root"), .other, .float(2), .bool(true)])
    }

    @Test
    func foldsBonesAndAppliesExpressionsOnApply() {
        var state = VMCPerformerState()
        let turn = simd_quatf(angle: 0.5, axis: SIMD3(0, 1, 0))

        let body = state.receive(TestOSC.bundle([
            TestOSC.bone("Head", position: SIMD3(0, 0.1, 0), rotation: turn),
            TestOSC.bone("Tail", position: .zero, rotation: turn),
            TestOSC.message("/VMC/Ext/Blend/Val", .string("Joy"), .float(1)),
        ]))
        #expect(body.movesBody)
        #expect(!body.appliesExpressions)
        #expect(state.expressions == nil)

        let face = state.receive(TestOSC.message("/VMC/Ext/Blend/Apply"))
        #expect(face.appliesExpressions)
        #expect(state.expressions == ["Joy": 1])

        let frame = VMCPerformerState.frame(fromResamplerValues: state.resamplerValues)
        #expect(frame.root == nil)
        #expect(frame.bones.keys.sorted { $0.rawValue < $1.rawValue } == [.head])
        let head = frame.bones[.head]
        #expect(head?.position == SIMD3(0, 0.1, 0))
        #expect(abs(simd_dot(head?.rotation.vector ?? .zero, turn.vector)) > 0.9999)
    }

    @Test
    func findsEveryBoneByItsName() {
        var state = VMCPerformerState()
        let bones = VMCBone.allCases.enumerated().map { index, bone in
            TestOSC.bone(bone.rawValue, position: SIMD3(Float(index), 0, 0), rotation: Self.identity)
        }

        _ = state.receive(TestOSC.bundle(bones))

        let frame = VMCPerformerState.frame(fromResamplerValues: state.resamplerValues)
        for (index, bone) in VMCBone.allCases.enumerated() {
            #expect(frame.bones[bone]?.position == SIMD3(Float(index), 0, 0), "\(bone)")
        }
        #expect(state.receive(TestOSC.bone("hips", position: .zero, rotation: Self.identity)).isEmpty)
    }

    @Test
    func readsTheRootAndIntegersButNotAnIncompleteOrNonFiniteTransform() {
        var state = VMCPerformerState()
        let root = TestOSC.message("/VMC/Ext/Root/Pos", .int(0), .float(1), .float(2), .float(3),
                                   .float(0), .float(0), .float(0), .int(2), .float(1), .float(1), .float(1))
        let incomplete = TestOSC.message("/VMC/Ext/Bone/Pos", .string("Hips"), .float(0), .float(0), .float(0),
                                         .float(0), .float(0), .float(0))
        let nonFinite = TestOSC.message("/VMC/Ext/Bone/Pos", .string("Spine"), .float(.infinity), .float(0), .float(0),
                                        .float(0), .float(0), .float(0), .float(1))
        let weight = TestOSC.message("/VMC/Ext/Blend/Val", .string("Joy"), .int(1))

        let apply = TestOSC.message("/VMC/Ext/Blend/Apply")
        _ = state.receive(TestOSC.bundle([root, incomplete, nonFinite, weight, apply]))

        let frame = VMCPerformerState.frame(fromResamplerValues: state.resamplerValues)
        #expect(frame.root?.position == SIMD3(1, 2, 3))
        #expect(frame.root?.rotation.vector == SIMD4(0, 0, 0, 1))
        #expect(frame.bones.isEmpty)
        #expect(state.expressions == ["Joy": 1])
    }

    @Test
    func keepsTheNamesOfTheWeightsWhenTheirOrderChanges() {
        var state = VMCPerformerState()
        func apply(_ weights: KeyValuePairs<String, Float>) -> [String: Float]? {
            let values = weights.map { TestOSC.message("/VMC/Ext/Blend/Val", .string($0.key), .float($0.value)) }
            _ = state.receive(TestOSC.bundle(values + [TestOSC.message("/VMC/Ext/Blend/Apply")]))
            return state.expressions
        }

        #expect(apply(["mouthLowerDownRight": 0.1, "Joy": 0.2]) == ["mouthLowerDownRight": 0.1, "Joy": 0.2])
        #expect(apply(["mouthLowerDownRight": 0.3, "Joy": 0.4]) == ["mouthLowerDownRight": 0.3, "Joy": 0.4])
        #expect(apply(["Joy": 0.5, "Angry": 0.6, "mouthLowerDownRight": 0.7])
            == ["Joy": 0.5, "Angry": 0.6, "mouthLowerDownRight": 0.7])
        #expect(apply(["Angry": 0.8]) == ["Angry": 0.8])
    }

    @Test
    func keepsEachRotationOnTheSideOfTheLastSoInterpolationStaysShort() {
        var state = VMCPerformerState()
        let turn = simd_quatf(angle: 0.5, axis: SIMD3(0, 1, 0))
        _ = state.receive(TestOSC.bone("Hips", position: .zero, rotation: turn))
        let first = state.resamplerValues

        _ = state.receive(TestOSC.bone("Hips", position: .zero, rotation: simd_quatf(vector: -turn.vector)))
        let second = state.resamplerValues

        // Root slot, then the hips: the rotation sits at 3..<7 of the hips' seven values
        #expect(Array(second[10..<14]) == Array(first[10..<14]))
    }
}

/// Builds OSC 1.0 packets the way a performer writes them
private enum TestOSC {
    static func message(_ address: String, _ arguments: OSCArgument...) -> Data {
        var tags = ","
        var payload = Data()
        for argument in arguments {
            switch argument {
            case .int(let value):
                tags += "i"
                payload += int32(UInt32(bitPattern: value))
            case .float(let value):
                tags += "f"
                payload += int32(value.bitPattern)
            case .string(let value):
                tags += "s"
                payload += string(value)
            case .bool(let value):
                tags += value ? "T" : "F"
            case .other:
                tags += "N"
            }
        }
        return string(address) + string(tags) + payload
    }

    static func bone(_ name: String, position: SIMD3<Float>, rotation: simd_quatf) -> Data {
        let r = rotation.vector
        return message("/VMC/Ext/Bone/Pos", .string(name), .float(position.x), .float(position.y), .float(position.z),
                       .float(r.x), .float(r.y), .float(r.z), .float(r.w))
    }

    static func bundle(_ elements: [Data]) -> Data {
        var data = string("#bundle") + Data(repeating: 0, count: 7) + Data([1])
        for element in elements {
            data += int32(UInt32(element.count)) + element
        }
        return data
    }

    static func string(_ value: String) -> Data {
        var data = Data(value.utf8)
        data.append(contentsOf: [UInt8](repeating: 0, count: 4 - data.count % 4))
        return data
    }

    static func int32(_ value: UInt32) -> Data {
        withUnsafeBytes(of: value.bigEndian) { Data($0) }
    }
}
