import SwiftUI
import VCamBridge
import VCamLogger

@MainActor
public final class RenderTextureManager {
    public static let shared = RenderTextureManager()

    private var recorders: [Int32: any RenderTextureRenderer] = [:]
    private var textures: [Int32: any MTLTexture] = [:]
    private let mtlDevice = MTLCreateSystemDefaultDevice()!
    // Streaming inputs differ every frame, so intermediate caching only wastes memory
    private lazy var ciContext = CIContext(mtlDevice: mtlDevice, options: [.cacheIntermediates: false, .name: "RenderTextureManager"])
    private lazy var commandQueue = mtlDevice.makeCommandQueue()

    public func add(_ recorder: any RenderTextureRenderer) -> Int32 {
        let id = Int32.random(in: 0..<Int32.max)
        set(recorder, id: id)
        return id
    }

    public func set(_ recorder: any RenderTextureRenderer, id: Int32) {
        uniDebugLog("Set rendertexture: \(id)")
        recorders[id] = recorder
    }

    public func drawer(id: Int32) -> (any RenderTextureRenderer)? {
        recorders[id]
    }

    public func texture(id: Int32) -> (any MTLTexture)? {
        textures[id]
    }

    func textRenderer(id: Int32) -> TextRenderer? {
        guard let renderer = recorders[id] as? TextRenderer, renderer.size.width > 0 else { return nil }
        return renderer
    }

    /// An existing texture of the same size is reused so that the object does not blink.
    public func allocateTexture(id: Int32, width: Int, height: Int) {
        let width = max(width, 1)
        let height = max(height, 1)
        if let texture = textures[id], texture.width == width, texture.height == height {
            setRenderTexture(texture, id: id)
            return
        }
        let wantsMipmap = recorders[id]?.isStaticSource ?? false
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm_srgb, width: width, height: height, mipmapped: wantsMipmap
        )
        // pixelFormatView for the linear view Core Image draws through; renderTarget only for
        // the blit that regenerates the mipmaps
        descriptor.usage = wantsMipmap
            ? [.shaderRead, .shaderWrite, .renderTarget, .pixelFormatView]
            : [.shaderRead, .shaderWrite, .pixelFormatView]
        descriptor.storageMode = .private
        guard let texture = mtlDevice.makeTexture(descriptor: descriptor) else {
            Logger.log("failed to allocate \(width)x\(height) for \(id)")
            return
        }
        textures[id] = texture
        setRenderTexture(texture, id: id)
    }

    private func setRenderTexture(_ texture: any MTLTexture, id: Int32) {
        uniDebugLog("setRenderTexture: \(id) in \(recorders.keys)")
        guard let recorder = recorders[id] else {
            uniDebugLog("setRenderTexture: no recorder \(id)")
            return
        }
        Logger.log("\(texture.width)x\(texture.height), \(type(of: recorder))")

        // Do not draw through the sRGB format, as the gamma correction makes it brighter
        guard let writeTarget = texture.makeTextureView(pixelFormat: .rgba8Unorm) else { return }
        // The target is fixed for this closure, so read its shape once instead of per frame
        let targetWidth = writeTarget.width
        let targetHeight = writeTarget.height
        let hasMipmaps = writeTarget.mipmapLevelCount > 1

        recorder.setRenderTexture { [self] image in
            let width = image.extent.width
            let height = image.extent.height
            if recorder.updateTextureSizeIfNeeded(imageWidth: width, imageHeight: height) {
                Logger.log("updateTextureSizeIfNeeded")
                // iPhone's screen size initially becomes 0x0, so reconfigure when a texture is retrieved.
                if let object = SceneObjectManager.shared.object(byId: id), let texture = object.type.croppableTexture {
                    texture.crop = recorder.cropRect
                    texture.region = .init(origin: .zero, size: .invalid)
                    recorder.disableRenderTexture()
                    Task { @MainActor in
                        SceneObjectManager.shared.update(object)
                    }
                    return
                }
            }

            let (camWidth, camHeight) = (Int(width * recorder.cropRect.width), Int(height * recorder.cropRect.height))
            if targetWidth == camWidth, targetHeight == camHeight {
                let croppedImage = recorder.cropped(of: image)
                // Core Image only writes the base level, so the blit rides the same command buffer
                // to stay ordered
                let commandBuffer = hasMipmaps ? commandQueue?.makeCommandBuffer() : nil
                ciContext.render(croppedImage, to: writeTarget, commandBuffer: commandBuffer, bounds: croppedImage.extent, colorSpace: .sRGB)
                if let commandBuffer {
                    if let blit = commandBuffer.makeBlitCommandEncoder() {
                        blit.generateMipmaps(for: writeTarget)
                        blit.endEncoding()
                    }
                    commandBuffer.commit()
                }
            } else {
                Logger.log("setRenderTexture change size: \(targetWidth) == \(camWidth), \(targetHeight) == \(camHeight), \(width)")
                recorder.disableRenderTexture()
                Task { @MainActor in
                    self.allocateTexture(id: id, width: camWidth, height: camHeight)
                }
            }
        }
    }

    func remove(id: Int32) {
        guard let recorder = recorders[id] else { return }
        recorder.stopRendering()
        recorders.removeValue(forKey: id)
        textures.removeValue(forKey: id)
    }

    func removeAll() {
        let ids = [Int32](recorders.keys)
        for id in ids {
            remove(id: id)
        }
    }

    public func pause() {
        for recorder in recorders.values {
            recorder.pauseRendering()
        }
    }

    public func resume() {
        for recorder in recorders.values {
            recorder.resumeRendering()
        }
    }
}
