//
//  MTLTexturePreview.swift
//
//
//  Created by Tatsuya Tanaka on 2023/10/07.
//

import SwiftUI
import MetalKit
import VCamBridge

public struct MTLTexturePreviewWindow: View {
    public init() {}
    
    public var body: some View {
        MTLTexturePreview(texture: MainTexture.shared.mtlTexture!)
            .frame(minWidth: 640, minHeight: 360)
            .aspectRatio(1280 / 720, contentMode: .fit)
    }
}

extension MTLTexturePreviewWindow: MacWindow {
    public var windowTitle: String {
        "Preview"
    }

    public func configureWindow(_ window: NSWindow) -> NSWindow {
        window.level = .floating
        window.styleMask = [.closable, .resizable, .fullSizeContentView]
        window.setContentSize(.init(width: 640, height: 360))
        window.hasShadow = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
        window.titlebarAppearsTransparent = true
        return window
    }
}

private struct MTLTexturePreview: NSViewRepresentable {
    let texture: any MTLTexture

    func makeNSView(context: Context) -> _MTLTexturePreview {
        _MTLTexturePreview(frame: .zero)
    }

    func updateNSView(_ nsView: _MTLTexturePreview, context: Context) {
        nsView.setTexture(texture)
    }
}

private final class _MTLTexturePreview: MTKView {
    private let commandQueue: any MTLCommandQueue
    private let vertexBuffer: any MTLBuffer
    private var pipelineState: (any MTLRenderPipelineState)?
    private var texture: (any MTLTexture)?

    required init(coder: NSCoder) {
        fatalError()
    }

    init(frame frameRect: CGRect) {
        let device = MTLCreateSystemDefaultDevice()!
        commandQueue = device.makeCommandQueue()!

        // [position.x, position.y, texCoord.x, texCoord.y]
        let vertices: [Float] = [
            -1,  1, 0, 1,
            -1, -1, 0, 0,
             1,  1, 1, 1,
             1, -1, 1, 0
        ]
        vertexBuffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<Float>.size * vertices.count, options: [])!

        super.init(frame: frameRect, device: device)

        framebufferOnly = false
        colorPixelFormat = .rgba8Unorm_srgb
        wantsLayer = true
        layer?.backgroundColor = .clear
        layer?.isOpaque = false

        let shader = """
        #include <metal_stdlib>
        using namespace metal;

        typedef struct {
            float2 position [[attribute(0)]];
            float2 texCoord [[attribute(1)]];
        } VertexInput;

        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };

        vertex VertexOut vertex_main(VertexInput in [[stage_in]]) {
            VertexOut outVertex;
            outVertex.position = float4(in.position, 0.0, 1.0);
            outVertex.texCoord = in.texCoord;
            return outVertex;
        }

        fragment float4 fragment_main(VertexOut vertexOut [[stage_in]], texture2d<float> texture [[texture(0)]]) {
            sampler smp = sampler(filter::linear);
            return texture.sample(smp, vertexOut.texCoord);
        }
        """

        let library = try! device.makeLibrary(source: shader, options: nil)
        let vertexFunction = library.makeFunction(name: "vertex_main")!
        let fragmentFunction = library.makeFunction(name: "fragment_main")!

        let vertexDescriptor = MTLVertexDescriptor()

        // Position attribute
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0

        // TexCoord attribute
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD2<Float>>.size

        vertexDescriptor.layouts[0].stride = 2 * MemoryLayout<SIMD2<Float>>.size

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexDescriptor = vertexDescriptor
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = colorPixelFormat

        pipelineState = try? device.makeRenderPipelineState(descriptor: descriptor)
    }

    func setTexture(_ texture: any MTLTexture) {
        self.texture = texture
    }

    override func draw(_ dirtyRect: CGRect) {
        guard
            let currentDrawable,
            let texture,
            let pipelineState,
            let descriptor = currentRenderPassDescriptor,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) 
        else { return }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()

        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
}
