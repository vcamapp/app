import CoreVideo
import Metal

/// Copies a rendered frame into a `CVPixelBuffer` with Metal.
///
/// The destination must be `kCVPixelFormatType_32BGRA` and Metal compatible
/// (`kCVPixelBufferMetalCompatibilityKey`), which also requires an IOSurface.
public final class MetalPixelBufferWriter {
    /// A frame from another device needs its own writer
    public let device: any MTLDevice

    /// Frames follow the compositor's convention (row 0 = bottom of the image) while
    /// pixel buffers are top-down, so the copy always flips vertically
    private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexOut {
        float4 position [[position]];
        float2 uv;
    };

    vertex VertexOut pixel_buffer_vertex(uint vid [[vertex_id]], constant uint &mirrored [[buffer(0)]]) {
        float2 corner = float2(vid & 1, vid >> 1);
        VertexOut out;
        out.position = float4(corner * 2 - 1, 0, 1);
        out.uv = float2(mirrored == 0 ? corner.x : 1 - corner.x, corner.y);
        return out;
    }

    fragment float4 pixel_buffer_fragment(VertexOut in [[stage_in]], texture2d<float> tex [[texture(0)]]) {
        constexpr sampler s(filter::linear, address::clamp_to_edge);
        return tex.sample(s, in.uv);
    }
    """

    private let pipeline: any MTLRenderPipelineState
    private let textureCache: CVMetalTextureCache
    private let pass = MTLRenderPassDescriptor()

    public init?(device: any MTLDevice) {
        var cache: CVMetalTextureCache?
        guard CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &cache) == kCVReturnSuccess,
              let cache,
              let library = try? device.makeLibrary(source: Self.shaderSource, options: nil),
              let vertexFunction = library.makeFunction(name: "pixel_buffer_vertex"),
              let fragmentFunction = library.makeFunction(name: "pixel_buffer_fragment") else { return nil }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        // The stored bytes are sRGB encoded on both sides, so sampling and writing cancel out
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
        guard let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor) else { return nil }

        self.device = device
        self.textureCache = cache
        self.pipeline = pipeline
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store
    }

    /// Encodes the copy and returns without waiting.
    ///
    /// - Parameter commandQueue: the queue the frame was composited on. Buffers committed to
    ///   one queue run in order, so the copy sees the finished frame without a fence.
    /// - Parameter completion: runs on a GPU thread once the copy has landed, which is
    ///   when the pixel buffer may be handed on.
    /// - Returns: false when the frame could not be encoded; the caller should drop it
    @discardableResult
    public func encode(
        _ source: any MTLTexture, to pixelBuffer: CVPixelBuffer, mirrored: Bool,
        on commandQueue: any MTLCommandQueue, completion: @escaping @Sendable () -> Void
    ) -> Bool {
        var cvTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault, textureCache, pixelBuffer, nil, .bgra8Unorm_srgb,
            CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer), 0, &cvTexture
        )
        guard status == kCVReturnSuccess, let cvTexture,
              let destination = CVMetalTextureGetTexture(cvTexture) else { return false }

        pass.colorAttachments[0].texture = destination
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return false }
        var mirroredFlag: UInt32 = mirrored ? 1 : 0
        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBytes(&mirroredFlag, length: MemoryLayout<UInt32>.size, index: 0)
        encoder.setFragmentTexture(source, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        // The texture keeps the pixel buffer mapped for the GPU, so it has to outlive the copy
        nonisolated(unsafe) let mapping = cvTexture
        commandBuffer.addCompletedHandler { _ in
            _ = mapping
            completion()
        }
        commandBuffer.commit()
        return true
    }
}
