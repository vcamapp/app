#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// An OSC 1.0 string, kept null-terminated and padded to a multiple of 4 bytes so that a name sent every frame
/// is encoded only once
public struct OSCString: Sendable {
    public let bytes: [UInt8]

    public init(_ string: String) {
        var bytes: [UInt8] = []
        bytes.appendOSCString(string)
        self.bytes = bytes
    }
}

/// Writes OSC 1.0 messages in order into bundles, starting a new bundle where the next message would not fit
/// in one datagram. Only the int32, float32 and string arguments the VMC Protocol uses are written.
/// A frame holds hundreds of messages, so they are written into one buffer instead of allocating per message
public struct OSCBundleWriter {
    /// The Ethernet MTU (1500) minus the IPv4 and UDP headers. A larger datagram is fragmented by IP,
    /// and losing a single fragment loses the whole bundle
    public static let maximumDatagramSize = 1472

    private static let header: [UInt8] = {
        var bytes: [UInt8] = []
        bytes.appendOSCString("#bundle")
        // The OSC timetag meaning "immediately"
        bytes.appendBigEndian(UInt64(1))
        return bytes
    }()

    private let maximumSize: Int
    private var datagrams: [Data] = []
    private var bundle: [UInt8] = []

    public init(maximumSize: Int = maximumDatagramSize) {
        self.maximumSize = maximumSize
        bundle.reserveCapacity(maximumSize)
        bundle.append(contentsOf: Self.header)
    }

    /// `typeTags` starts with `,` and must match what `arguments` writes.
    /// A message larger than the limit on its own gets a bundle of its own
    public mutating func appendMessage(_ address: OSCString, typeTags: OSCString,
                                       arguments: (inout OSCBundleWriter) -> Void = { _ in }) {
        let sizeOffset = bundle.count
        // The size is filled in once the message is written
        bundle.appendBigEndian(UInt32(0))
        bundle.append(contentsOf: address.bytes)
        bundle.append(contentsOf: typeTags.bytes)
        arguments(&self)
        let size = UInt32(bundle.count - sizeOffset - 4).bigEndian
        withUnsafeBytes(of: size) { bundle.replaceSubrange(sizeOffset..<sizeOffset + 4, with: $0) }

        if sizeOffset > Self.header.count, bundle.count > maximumSize {
            datagrams.append(Data(bundle[..<sizeOffset]))
            bundle.removeSubrange(Self.header.count..<sizeOffset)
        }
    }

    public mutating func append(_ value: Int32) {
        bundle.appendBigEndian(UInt32(bitPattern: value))
    }

    public mutating func append(_ value: Float) {
        bundle.appendBigEndian(value.bitPattern)
    }

    public mutating func append(_ string: OSCString) {
        bundle.append(contentsOf: string.bytes)
    }

    public mutating func append(_ string: String) {
        bundle.appendOSCString(string)
    }

    /// Empty when no message was written
    public consuming func finish() -> [Data] {
        if bundle.count > Self.header.count {
            datagrams.append(Data(bundle))
        }
        return datagrams
    }
}

private extension [UInt8] {
    mutating func appendOSCString(_ string: String) {
        append(contentsOf: string.utf8)
        // The terminating null is part of the padding to a multiple of 4 bytes
        for _ in 0..<4 - string.utf8.count % 4 {
            append(0)
        }
    }

    mutating func appendBigEndian<T: FixedWidthInteger>(_ value: T) {
        Swift.withUnsafeBytes(of: value.bigEndian) { append(contentsOf: $0) }
    }
}
