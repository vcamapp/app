//
//  MTLTextureStub.swift
//
//
//  Created by Tatsuya Tanaka on 2023/10/07.
//

import MetalKit

public enum MTLTextureStub {
    public static func makeMainTexture() -> any MTLTexture {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm_srgb, width: 1280, height: 720, mipmapped: false)
        textureDescriptor.usage = [.shaderRead, .shaderWrite, .pixelFormatView]
        let texture = MTLCreateSystemDefaultDevice()!.makeTexture(descriptor: textureDescriptor)!
        let origin = MTLOrigin(x: 0, y: 0, z: 0)
        let size = MTLSize(width: texture.width, height: texture.height, depth: texture.depth)
        let region = MTLRegion(origin: origin, size: size)
        let mappedColor = simd_uchar4(simd_float4(1, 0, 0, 0) * 255)
        Array<simd_uchar4>(repeating: mappedColor, count: 1280 * 720).withUnsafeBytes { ptr in
            texture.replace(region: region, mipmapLevel: 0, withBytes: ptr.baseAddress!, bytesPerRow: 1280 * 4)
        }

        return texture
    }
}
