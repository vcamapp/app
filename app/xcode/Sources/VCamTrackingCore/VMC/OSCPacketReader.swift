#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

package enum OSCArgument: Equatable, Sendable {
    case int(Int32)
    case float(Float)
    case string(String)
    case bool(Bool)
    /// A type the VMC Protocol does not use, kept so the positions of the arguments after it stay the same
    case other
}

package struct OSCMessage: Equatable, Sendable {
    package var address: String
    package var arguments: [OSCArgument]

    package init(address: String, arguments: [OSCArgument]) {
        self.address = address
        self.arguments = arguments
    }

    package func string(at index: Int) -> String? {
        guard arguments.indices.contains(index), case .string(let value) = arguments[index] else { return nil }
        return value
    }

    /// Senders differ in whether they write a weight as a float or an int
    package func float(at index: Int) -> Float? {
        guard arguments.indices.contains(index) else { return nil }
        switch arguments[index] {
        case .float(let value): return value
        case .int(let value): return Float(value)
        default: return nil
        }
    }
}

/// Reads OSC 1.0 packets: a message, or a bundle of messages and bundles, flattened in order.
/// Timetags are ignored. A malformed message is dropped, and a bundle ends where its framing breaks
package enum OSCPacketReader {
    package static func messages(in data: Data) -> [OSCMessage] {
        data.withUnsafeBytes { bytes in
            var messages: [OSCMessage] = []
            var reader = Reader(bytes: bytes, range: 0..<bytes.count)
            readPacket(&reader, into: &messages)
            return messages
        }
    }

    private static let bundleTag = Array("#bundle".utf8) + [0]

    private static func readPacket(_ reader: inout Reader, into messages: inout [OSCMessage]) {
        if reader.hasPrefix(bundleTag) {
            readBundle(&reader, into: &messages)
        } else if let message = readMessage(&reader) {
            messages.append(message)
        }
    }

    private static func readBundle(_ reader: inout Reader, into messages: inout [OSCMessage]) {
        // The tag and the 8-byte timetag
        guard reader.skip(bundleTag.count + 8) else { return }
        while !reader.isAtEnd {
            guard let size = reader.int32(), size >= 0, var element = reader.subReader(count: Int(size)) else { return }
            readPacket(&element, into: &messages)
        }
    }

    private static func readMessage(_ reader: inout Reader) -> OSCMessage? {
        guard let address = reader.string(), address.hasPrefix("/") else { return nil }
        // A message without a type tag string is allowed by OSC 1.0 and carries no arguments
        guard !reader.isAtEnd else { return OSCMessage(address: address, arguments: []) }
        guard let typeTags = reader.string(), typeTags.hasPrefix(",") else { return nil }
        var arguments: [OSCArgument] = []
        arguments.reserveCapacity(typeTags.utf8.count - 1)
        for tag in typeTags.utf8.dropFirst() {
            guard let argument = readArgument(tag, from: &reader) else { return nil }
            arguments.append(argument)
        }
        return OSCMessage(address: address, arguments: arguments)
    }

    private static func readArgument(_ tag: UInt8, from reader: inout Reader) -> OSCArgument? {
        switch tag {
        case UInt8(ascii: "i"): reader.int32().map(OSCArgument.int)
        case UInt8(ascii: "f"): reader.int32().map { .float(Float(bitPattern: UInt32(bitPattern: $0))) }
        case UInt8(ascii: "s"), UInt8(ascii: "S"): reader.string().map(OSCArgument.string)
        case UInt8(ascii: "T"): .bool(true)
        case UInt8(ascii: "F"): .bool(false)
        case UInt8(ascii: "N"), UInt8(ascii: "I"): .other
        case UInt8(ascii: "c"), UInt8(ascii: "r"), UInt8(ascii: "m"): reader.skip(4) ? .other : nil
        case UInt8(ascii: "h"), UInt8(ascii: "t"), UInt8(ascii: "d"): reader.skip(8) ? .other : nil
        case UInt8(ascii: "b"):
            reader.int32().flatMap { size in size >= 0 && reader.skip(padded(Int(size))) ? .other : nil }
        default:
            // The size of an unknown type is unknown, so nothing after it can be read
            nil
        }
    }

    private static func padded(_ count: Int) -> Int {
        (count + 3) & ~3
    }

    private struct Reader {
        let bytes: UnsafeRawBufferPointer
        var range: Range<Int>

        var isAtEnd: Bool { range.isEmpty }

        func hasPrefix(_ prefix: [UInt8]) -> Bool {
            range.count >= prefix.count && prefix.indices.allSatisfy { bytes[range.lowerBound + $0] == prefix[$0] }
        }

        mutating func skip(_ count: Int) -> Bool {
            guard count <= range.count else { return false }
            range = (range.lowerBound + count)..<range.upperBound
            return true
        }

        mutating func int32() -> Int32? {
            guard range.count >= 4 else { return nil }
            let start = range.lowerBound
            let value = (UInt32(bytes[start]) << 24) | (UInt32(bytes[start + 1]) << 16)
                | (UInt32(bytes[start + 2]) << 8) | UInt32(bytes[start + 3])
            _ = skip(4)
            return Int32(bitPattern: value)
        }

        /// A null-terminated string padded to a multiple of 4 bytes
        mutating func string() -> String? {
            guard let end = range.first(where: { bytes[$0] == 0 }) else { return nil }
            let value = String(decoding: UnsafeRawBufferPointer(rebasing: bytes[range.lowerBound..<end]), as: UTF8.self)
            // Some senders leave out the padding after the last string of a packet
            _ = skip(min(OSCPacketReader.padded(end - range.lowerBound + 1), range.count))
            return value
        }

        mutating func subReader(count: Int) -> Reader? {
            guard count <= range.count else { return nil }
            let sub = Reader(bytes: bytes, range: range.lowerBound..<(range.lowerBound + count))
            _ = skip(count)
            return sub
        }
    }
}
