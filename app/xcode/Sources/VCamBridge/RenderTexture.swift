//
//  RenderTexture.swift
//
//
//  Created by Tatsuya Tanaka on 2022/03/25.
//

import MetalKit

public enum RenderTextureType: Int32 {
    case photo
    case screen
    case captureDevice
    case web
}

public final class MainTexture {
    public static let shared = MainTexture()

    public private(set) var texture = CIImage(color: .black).cropped(to: .init(x: 0, y: 0, width: 1280, height: 720))
    public private(set) var mtlTexture: (any MTLTexture)?

    public var aspectRatio: Float {
        let size = texture.extent.size
        return Float(size.height / size.width)
    }

    public var isLandscape: Bool {
        aspectRatio <= 1
    }

    public func setTexture(_ texture: any MTLTexture) {
        self.mtlTexture = texture
        self.texture = CIImage(mtlTexture: texture, options: nil)!
    }
}

public func __bridge<T : AnyObject>(_ ptr: UnsafeRawPointer) -> T {
    Unmanaged.fromOpaque(ptr).takeUnretainedValue()
}

@_cdecl("uniRegisterMainTexture")
public func uniRegisterMainTexture(imagePointer: UnsafeRawPointer?) {
    guard let imagePointer else { return }
    let bridgedMtlTexture: any MTLTexture = __bridge(imagePointer)

#if FOR_DEBUG
    os_log(.debug, " \(String(describing: bridgedMtlTexture).dropFirst(80), privacy: .public)")
#endif

//    let mtlTexture = bridgedMtlTexture.makeTextureView(pixelFormat: .rgba8Unorm_srgb)!
    MainTexture.shared.setTexture(bridgedMtlTexture)
}



/* Information about the main texture

 <AGXG13XFamilyTexture: 0x12e87f730>
     label =
     textureType = MTLTextureType2D
     pixelFormat = MTLPixelFormatRGBA8Unorm_sRGB
     width = 1920
     height = 1080
     depth = 1
     arrayLength = 1
     mipmapLevelCount = 1
     sampleCount = 1
     cpuCacheMode = MTLCPUCacheModeDefaultCache
     storageMode = MTLStorageModeShared
     hazardTrackingMode = MTLHazardTrackingModeTracked
     resourceOptions = MTLResourceCPUCacheModeDefaultCache MTLResourceStorageModeShared MTLResourceHazardTrackingModeTracked
     usage = MTLTextureUsageShaderRead MTLTextureUsageRenderTarget
     shareable = 0
     framebufferOnly = 0
     purgeableState = MTLPurgeableStateNonVolatile
     swizzle = [MTLTextureSwizzleRed, MTLTextureSwizzleGreen, MTLTextureSwizzleBlue, MTLTextureSwizzleAlpha]
     isCompressed = 1
     parentTexture = <null>
     parentRelativeLevel = 0
     parentRelativeSlice = 0
     buffer = <null>
     bufferOffset = 0
     bufferBytesPerRow = 0
     iosurface = 0x0
     iosurfacePlane = 0
     allowGPUOptimizedContents = YES
 */
