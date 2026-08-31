import CoreImage
import CoreVideo
import Synchronization
import Metal
import Testing
@testable import VCamMedia

/// Core Image is the oracle: `CIImage(mtlTexture:)` rendered into the same pixel buffer
/// must give the same bytes as the Metal copy.
///
/// Lives with the virtual camera's tests because that is the writer's main caller and
/// VCamMedia has no test target of its own.
@Suite
struct MetalPixelBufferWriterTests {
    /// sRGB encode/decode round trips through the GPU, so allow the last bit
    private static let tolerance = 1

    @Test(arguments: [false, true])
    func matchesCoreImage(mirrored: Bool) throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let writer = try #require(MetalPixelBufferWriter(device: device))
        let width = 64, height = 32
        let source = try Self.makeSource(device: device, width: width, height: height)

        let queue = try #require(device.makeCommandQueue())
        let actual = try Self.makePixelBuffer(width: width, height: height)
        let done = DispatchSemaphore(value: 0)
        #expect(writer.encode(source, to: actual, mirrored: mirrored, on: queue) { done.signal() })
        #expect(done.wait(timeout: .now() + 5) == .success)

        let expected = try Self.makePixelBuffer(width: width, height: height)
        let image = try #require(CIImage(mtlTexture: source, options: nil))
        CIContext(options: [.cacheIntermediates: false])
            .render(mirrored ? image.oriented(.upMirrored) : image, to: expected)

        try Self.expectEqual(actual, expected)
    }

    /// The recording appends frames in completion order, so the copies must land in the order
    /// they were encoded. Command buffers committed to one queue complete in order; this
    /// pins that assumption.
    @Test
    func completionsRunInTheOrderTheyWereEncoded() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let writer = try #require(MetalPixelBufferWriter(device: device))
        let queue = try #require(device.makeCommandQueue())
        let source = try Self.makeSource(device: device, width: 64, height: 32)
        let frames = 20

        let order = Mutex<[Int]>([])
        let done = DispatchSemaphore(value: 0)
        for index in 0..<frames {
            let buffer = try Self.makePixelBuffer(width: 64, height: 32)
            #expect(writer.encode(source, to: buffer, mirrored: false, on: queue) {
                order.withLock { $0.append(index) }
                done.signal()
            })
        }
        for _ in 0..<frames {
            #expect(done.wait(timeout: .now() + 5) == .success)
        }
        #expect(order.withLock { $0 } == Array(0..<frames))
    }

    /// A frame with no symmetry at all, so a flip in either axis shows up
    private static func makeSource(device: any MTLDevice, width: Int, height: Int) throws -> any MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm_srgb, width: width, height: height, mipmapped: false
        )
        descriptor.usage = [.shaderRead]
        let texture = try #require(device.makeTexture(descriptor: descriptor))
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                bytes[offset] = UInt8(x * 255 / (width - 1))          // B: varies along x
                bytes[offset + 1] = UInt8(y * 255 / (height - 1))     // G: varies along y
                bytes[offset + 2] = UInt8((x + y) % 256)
                bytes[offset + 3] = 255
            }
        }
        bytes.withUnsafeBytes {
            texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
                            withBytes: $0.baseAddress!, bytesPerRow: width * 4)
        }
        return texture
    }

    private static func makePixelBuffer(width: Int, height: Int) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, [
            kCVPixelBufferIOSurfacePropertiesKey: [:],
            kCVPixelBufferMetalCompatibilityKey: true,
        ] as CFDictionary, &buffer)
        return try #require(buffer)
    }

    private static func expectEqual(_ lhs: CVPixelBuffer, _ rhs: CVPixelBuffer) throws {
        CVPixelBufferLockBaseAddress(lhs, .readOnly)
        CVPixelBufferLockBaseAddress(rhs, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(lhs, .readOnly)
            CVPixelBufferUnlockBaseAddress(rhs, .readOnly)
        }
        let width = CVPixelBufferGetWidth(lhs)
        let height = CVPixelBufferGetHeight(lhs)
        let lhsBase = try #require(CVPixelBufferGetBaseAddress(lhs)).assumingMemoryBound(to: UInt8.self)
        let rhsBase = try #require(CVPixelBufferGetBaseAddress(rhs)).assumingMemoryBound(to: UInt8.self)
        let lhsStride = CVPixelBufferGetBytesPerRow(lhs)
        let rhsStride = CVPixelBufferGetBytesPerRow(rhs)

        for y in 0..<height {
            for x in 0..<width {
                for channel in 0..<4 {
                    let a = Int(lhsBase[y * lhsStride + x * 4 + channel])
                    let b = Int(rhsBase[y * rhsStride + x * 4 + channel])
                    #expect(abs(a - b) <= tolerance, "(\(x), \(y)) ch\(channel): \(a) vs \(b)")
                }
            }
        }
    }
}
