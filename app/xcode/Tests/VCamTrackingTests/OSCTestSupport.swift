import Foundation
@testable import VCamTrackingCore

/// An argument as the reader read it, copied out of the packet so that tests can keep and compare it
enum OSCArgument: Equatable {
    case int(Int32)
    case float(Float)
    case string(String)
    case bool(Bool)
    case other

    init(_ argument: OSCArgumentView) {
        switch argument {
        case .int(let value): self = .int(value)
        case .float(let value): self = .float(value)
        case .string(let value): self = .string(String(decoding: value, as: UTF8.self))
        case .bool(let value): self = .bool(value)
        case .other: self = .other
        }
    }
}

struct OSCMessage: Equatable {
    var address: String
    var arguments: [OSCArgument]

    func string(at index: Int) -> String? {
        guard arguments.indices.contains(index), case .string(let value) = arguments[index] else { return nil }
        return value
    }
}

extension OSCPacketReader {
    static func messages(in packet: Data) -> [OSCMessage] {
        packet.withUnsafeBytes { bytes in
            var messages: [OSCMessage] = []
            forEachMessage(in: bytes) { message in
                messages.append(OSCMessage(address: String(decoding: message.address, as: UTF8.self),
                                           arguments: message.arguments.map(OSCArgument.init)))
            }
            return messages
        }
    }
}
