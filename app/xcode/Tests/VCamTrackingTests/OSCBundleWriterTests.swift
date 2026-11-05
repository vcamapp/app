import Foundation
import Testing
@testable import VCamTrackingCore

@Suite
struct OSCBundleWriterTests {
    private static let bundleHeader = Data("#bundle".utf8) + Data([0]) + Data([0, 0, 0, 0, 0, 0, 0, 1])

    @Test
    func messageIsPaddedToFourBytesAndBigEndian() throws {
        var writer = OSCBundleWriter()
        writer.appendMessage(OSCString("/VMC/Ext/OK"), typeTags: OSCString(",ifs")) {
            $0.append(Int32(1))
            $0.append(Float(1))
            $0.append("Head")
        }
        let datagram = try #require(writer.finish().first)

        var message = Data("/VMC/Ext/OK".utf8) + Data([0])
        message += Data(",ifs".utf8) + Data([0, 0, 0, 0])
        message += Data([0, 0, 0, 1])
        message += Data([0x3F, 0x80, 0, 0])
        message += Data("Head".utf8) + Data([0, 0, 0, 0])
        #expect(datagram == Self.bundleHeader + Data([0, 0, 0, UInt8(message.count)]) + message)
    }

    @Test
    func messageWithoutArgumentsKeepsTheEmptyTypeTag() throws {
        var writer = OSCBundleWriter()
        writer.appendMessage(OSCString("/VMC/Ext/Blend/Apply"), typeTags: OSCString(","))
        let datagram = try #require(writer.finish().first)

        let message = Data("/VMC/Ext/Blend/Apply".utf8) + Data([0, 0, 0, 0]) + Data(",".utf8) + Data([0, 0, 0])
        #expect(datagram == Self.bundleHeader + Data([0, 0, 0, UInt8(message.count)]) + message)
    }

    @Test
    func readerReadsWhatTheWriterWrites() {
        var writer = OSCBundleWriter()
        writer.appendMessage(OSCString("/VMC/Ext/OK"), typeTags: OSCString(",i")) { $0.append(Int32(-7)) }
        writer.appendMessage(OSCString("/VMC/Ext/Bone/Pos"), typeTags: OSCString(",sfffffff")) {
            $0.append(OSCString("LeftUpperArm"))
            for value: Float in [0.1, -0.2, 0.3, 0, 0.5, -0.5, 0.70710677] {
                $0.append(value)
            }
        }
        // A name filling exactly 4 bytes still gets its terminating null
        writer.appendMessage(OSCString("/VMC/Ext/Blend/Val"), typeTags: OSCString(",sf")) {
            $0.append("Joy!")
            $0.append(Float(0.25))
        }
        writer.appendMessage(OSCString("/VMC/Ext/Blend/Apply"), typeTags: OSCString(","))

        let messages = writer.finish().flatMap(OSCPacketReader.messages(in:))

        #expect(messages == [
            OSCMessage(address: "/VMC/Ext/OK", arguments: [.int(-7)]),
            OSCMessage(address: "/VMC/Ext/Bone/Pos", arguments: [.string("LeftUpperArm")]
                + [0.1, -0.2, 0.3, 0, 0.5, -0.5, 0.70710677].map(OSCArgument.float)),
            OSCMessage(address: "/VMC/Ext/Blend/Val", arguments: [.string("Joy!"), .float(0.25)]),
            OSCMessage(address: "/VMC/Ext/Blend/Apply", arguments: []),
        ])
    }

    @Test
    func bundlesFitInADatagramAndKeepTheMessageOrder() {
        var writer = OSCBundleWriter()
        for index in 0..<200 {
            writer.appendMessage(OSCString("/VMC/Ext/Blend/Val"), typeTags: OSCString(",sf")) {
                $0.append("Shape\(index)")
                $0.append(Float(index))
            }
        }
        let datagrams = writer.finish()

        #expect(datagrams.count > 1)
        #expect(datagrams.allSatisfy { $0.count <= OSCBundleWriter.maximumDatagramSize })
        #expect(datagrams.flatMap(OSCPacketReader.messages(in:)) == (0..<200).map {
            OSCMessage(address: "/VMC/Ext/Blend/Val", arguments: [.string("Shape\($0)"), .float(Float($0))])
        })
    }

    @Test
    func messageOverTheLimitGetsItsOwnBundle() {
        let names = ["Short", String(repeating: "Long", count: 20), "Next"]
        var writer = OSCBundleWriter(maximumSize: 64)
        for name in names {
            writer.appendMessage(OSCString("/VMC/Ext/Blend/Val"), typeTags: OSCString(",sf")) {
                $0.append(name)
                $0.append(Float(1))
            }
        }

        let datagrams = writer.finish()

        #expect(datagrams.map { OSCPacketReader.messages(in: $0).map { $0.string(at: 0) } } == names.map { [$0] })
    }

    @Test
    func emptyMessagesMakeNoDatagram() {
        #expect(OSCBundleWriter().finish().isEmpty)
    }
}
