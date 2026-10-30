import Foundation
import simd
import Testing
@testable import VCamTrackingCore

@Suite
struct VMCProtocolTests {
    @Test
    func readsTheMessagesOfNestedBundles() {
        let bone = TestOSC.message("/VMC/Ext/Bone/Pos", .string("Hips"), .float(0), .float(0.9), .float(0),
                                   .float(0), .float(0), .float(0), .float(1))
        let blend = TestOSC.message("/VMC/Ext/Blend/Val", .string("Joy"), .float(0.5))
        let packet = TestOSC.bundle([bone, TestOSC.bundle([blend]), TestOSC.message("/VMC/Ext/Blend/Apply")])

        let messages = OSCPacketReader.messages(in: packet)

        #expect(messages.map(\.address) == ["/VMC/Ext/Bone/Pos", "/VMC/Ext/Blend/Val", "/VMC/Ext/Blend/Apply"])
        #expect(messages[0].arguments.first == .string("Hips"))
        #expect(messages[0].float(at: 2) == 0.9)
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

        let body = state.receive(OSCPacketReader.messages(in: TestOSC.bundle([
            TestOSC.bone("Head", position: SIMD3(0, 0.1, 0), rotation: turn),
            TestOSC.bone("Tail", position: .zero, rotation: turn),
            TestOSC.message("/VMC/Ext/Blend/Val", .string("Joy"), .float(1)),
        ])))
        #expect(body.movesBody)
        #expect(!body.appliesExpressions)
        #expect(state.expressions == nil)

        let face = state.receive([OSCMessage(address: "/VMC/Ext/Blend/Apply", arguments: [])])
        #expect(face.appliesExpressions)
        #expect(state.expressions == ["Joy": 1])

        let frame = VMCPerformerState.frame(fromResamplerValues: state.resamplerValues, expressions: nil)
        #expect(frame.root == nil)
        #expect(frame.bones.keys.sorted { $0.rawValue < $1.rawValue } == [.head])
        let head = frame.bones[.head]
        #expect(head?.position == SIMD3(0, 0.1, 0))
        #expect(abs(simd_dot(head?.rotation.vector ?? .zero, turn.vector)) > 0.9999)
    }

    @Test
    func keepsEachRotationOnTheSideOfTheLastSoInterpolationStaysShort() {
        var state = VMCPerformerState()
        let turn = simd_quatf(angle: 0.5, axis: SIMD3(0, 1, 0))
        _ = state.receive([TestOSC.boneMessage("Hips", rotation: turn)])
        let first = state.resamplerValues

        _ = state.receive([TestOSC.boneMessage("Hips", rotation: simd_quatf(vector: -turn.vector))])
        let second = state.resamplerValues

        // Root slot, then the hips: the rotation sits at 3..<7 of the hips' seven values
        #expect(Array(second[10..<14]) == Array(first[10..<14]))
    }
}

/// Builds OSC 1.0 packets the way a performer writes them
private enum TestOSC {
    enum Argument {
        case string(String)
        case float(Float)
    }

    static func message(_ address: String, _ arguments: Argument...) -> Data {
        var tags = ","
        var payload = Data()
        for argument in arguments {
            switch argument {
            case .string(let value):
                tags += "s"
                payload += string(value)
            case .float(let value):
                tags += "f"
                payload += int32(value.bitPattern)
            }
        }
        return string(address) + string(tags) + payload
    }

    static func bone(_ name: String, position: SIMD3<Float>, rotation: simd_quatf) -> Data {
        let r = rotation.vector
        return message("/VMC/Ext/Bone/Pos", .string(name), .float(position.x), .float(position.y), .float(position.z),
                       .float(r.x), .float(r.y), .float(r.z), .float(r.w))
    }

    static func boneMessage(_ name: String, rotation: simd_quatf) -> OSCMessage {
        OSCPacketReader.messages(in: bone(name, position: .zero, rotation: rotation))[0]
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
