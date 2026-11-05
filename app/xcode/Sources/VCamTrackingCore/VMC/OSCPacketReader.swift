/// Reads OSC 1.0 packets in place: a message, or a bundle of messages and bundles, visited in order.
/// Timetags are ignored. A malformed message is skipped, and a bundle ends where its framing breaks
package enum OSCPacketReader {
    /// Each message points into `packet`, so `body` must not keep it
    package static func forEachMessage(in packet: UnsafeRawBufferPointer, _ body: (OSCMessageView) -> Void) {
        var reader = OSCByteReader(bytes: packet, range: 0..<packet.count)
        readPacket(&reader, body)
    }

    private static let bundleTag: StaticString = "#bundle"

    private static func readPacket(_ reader: inout OSCByteReader, _ body: (OSCMessageView) -> Void) {
        if reader.hasPrefix(bundleTag) {
            readBundle(&reader, body)
        } else if let message = OSCMessageView(&reader) {
            body(message)
        }
    }

    private static func readBundle(_ reader: inout OSCByteReader, _ body: (OSCMessageView) -> Void) {
        // The tag with its null, and the 8-byte timetag
        guard reader.skip(bundleTag.utf8CodeUnitCount + 1 + 8) else { return }
        while !reader.isAtEnd {
            guard let size = reader.int32(), size >= 0, var element = reader.subReader(count: Int(size)) else { return }
            readPacket(&element, body)
        }
    }
}

/// A message of the packet being read
package struct OSCMessageView {
    /// Without the terminating null
    package let address: UnsafeRawBufferPointer
    /// Without the leading comma
    private let typeTags: UnsafeRawBufferPointer
    private let payload: OSCByteReader

    /// nil when the message is malformed anywhere, so that a message is either read whole or not at all
    fileprivate init?(_ reader: inout OSCByteReader) {
        guard let address = reader.string(), address.first == UInt8(ascii: "/") else { return nil }
        self.address = address
        // A message without a type tag string is allowed by OSC 1.0 and carries no arguments
        guard !reader.isAtEnd else {
            typeTags = UnsafeRawBufferPointer(start: nil, count: 0)
            payload = reader
            return
        }
        guard let typeTags = reader.string(), typeTags.first == UInt8(ascii: ",") else { return nil }
        self.typeTags = UnsafeRawBufferPointer(rebasing: typeTags.dropFirst())
        payload = reader
        var arguments = self.arguments
        while arguments.hasNext {
            guard arguments.next() != nil else { return nil }
        }
    }

    package func hasAddress(_ address: StaticString) -> Bool {
        address.withUTF8Buffer { self.address.count == $0.count && self.address.elementsEqual($0) }
    }

    package var arguments: OSCArguments {
        OSCArguments(typeTags: typeTags, reader: payload)
    }
}

package struct OSCArguments: Sequence, IteratorProtocol {
    private let typeTags: UnsafeRawBufferPointer
    private var tagIndex = 0
    private var reader: OSCByteReader

    fileprivate init(typeTags: UnsafeRawBufferPointer, reader: OSCByteReader) {
        self.typeTags = typeTags
        self.reader = reader
    }

    fileprivate var hasNext: Bool { tagIndex < typeTags.count }

    package mutating func next() -> OSCArgumentView? {
        guard hasNext else { return nil }
        let tag = typeTags[tagIndex]
        tagIndex += 1
        return reader.argument(tag)
    }
}

package enum OSCArgumentView {
    case int(Int32)
    case float(Float)
    /// Without the terminating null, pointing into the packet
    case string(UnsafeRawBufferPointer)
    case bool(Bool)
    /// A type the VMC Protocol does not use, kept so the positions of the arguments after it stay the same
    case other

    /// Senders differ in whether they write a weight as a float or an int
    package var number: Float? {
        switch self {
        case .float(let value): value
        case .int(let value): Float(value)
        case .string, .bool, .other: nil
        }
    }
}

private struct OSCByteReader {
    let bytes: UnsafeRawBufferPointer
    var range: Range<Int>

    var isAtEnd: Bool { range.isEmpty }

    func hasPrefix(_ prefix: StaticString) -> Bool {
        prefix.withUTF8Buffer { prefix in
            range.count > prefix.count && bytes[range.lowerBound + prefix.count] == 0
                && prefix.indices.allSatisfy { bytes[range.lowerBound + $0] == prefix[$0] }
        }
    }

    mutating func skip(_ count: Int) -> Bool {
        guard count <= range.count else { return false }
        range = (range.lowerBound + count)..<range.upperBound
        return true
    }

    mutating func int32() -> Int32? {
        guard range.count >= 4 else { return nil }
        let value = UInt32(bigEndian: bytes.loadUnaligned(fromByteOffset: range.lowerBound, as: UInt32.self))
        _ = skip(4)
        return Int32(bitPattern: value)
    }

    /// A null-terminated string padded to a multiple of 4 bytes
    mutating func string() -> UnsafeRawBufferPointer? {
        var end = range.lowerBound
        while end < range.upperBound, bytes[end] != 0 {
            end += 1
        }
        guard end < range.upperBound else { return nil }
        let value = UnsafeRawBufferPointer(rebasing: bytes[range.lowerBound..<end])
        // Some senders leave out the padding after the last string of a packet
        _ = skip(min(Self.padded(end - range.lowerBound + 1), range.count))
        return value
    }

    mutating func subReader(count: Int) -> OSCByteReader? {
        guard count <= range.count else { return nil }
        let sub = OSCByteReader(bytes: bytes, range: range.lowerBound..<(range.lowerBound + count))
        _ = skip(count)
        return sub
    }

    mutating func argument(_ tag: UInt8) -> OSCArgumentView? {
        switch tag {
        case UInt8(ascii: "i"): int32().map(OSCArgumentView.int)
        case UInt8(ascii: "f"): int32().map { .float(Float(bitPattern: UInt32(bitPattern: $0))) }
        case UInt8(ascii: "s"), UInt8(ascii: "S"): string().map(OSCArgumentView.string)
        case UInt8(ascii: "T"): .bool(true)
        case UInt8(ascii: "F"): .bool(false)
        case UInt8(ascii: "N"), UInt8(ascii: "I"): .other
        case UInt8(ascii: "c"), UInt8(ascii: "r"), UInt8(ascii: "m"): skip(4) ? .other : nil
        case UInt8(ascii: "h"), UInt8(ascii: "t"), UInt8(ascii: "d"): skip(8) ? .other : nil
        case UInt8(ascii: "b"):
            int32().flatMap { size in size >= 0 && skip(Self.padded(Int(size))) ? .other : nil }
        default:
            // The size of an unknown type is unknown, so nothing after it can be read
            nil
        }
    }

    private static func padded(_ count: Int) -> Int {
        (count + 3) & ~3
    }
}
