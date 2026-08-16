import SwiftUI
import VCamBridge
import VCamLogger

@MainActor
public final class RenderTextureManager {
    public static let shared = RenderTextureManager()

    private var recorders: [Int32: any RenderTextureRenderer] = [:]
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

    /// The text renderer for an object, once it has something to draw
    func textRenderer(id: Int32) -> TextRenderer? {
        guard let renderer = recorders[id] as? TextRenderer, renderer.size.width > 0 else { return nil }
        return renderer
    }

    public func setRenderTexture(_ texture: any MTLTexture, id: Int32) {
        uniDebugLog("setRenderTexture: \(id) in \(recorders.keys)")
        guard let recorder = recorders[id] else {
            uniDebugLog("setRenderTexture: no recorder \(id)")
            return
        }
        Logger.log("\(texture.width)x\(texture.height), \(type(of: recorder))")

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
            if texture.width == camWidth, texture.height == camHeight {
                let croppedImage = recorder.cropped(of: image)
                // The engine draws its preview scaled to the window, so a mipmapped texture is
                // the only way thin strokes survive minification. Core Image only writes the
                // base level, so the blit has to ride the same command buffer to stay ordered.
                let commandBuffer = texture.mipmapLevelCount > 1 ? commandQueue?.makeCommandBuffer() : nil
                ciContext.render(croppedImage, to: texture, commandBuffer: commandBuffer, bounds: croppedImage.extent, colorSpace: .sRGB)
                if let commandBuffer {
                    if let blit = commandBuffer.makeBlitCommandEncoder() {
                        blit.generateMipmaps(for: texture)
                        blit.endEncoding()
                    }
                    commandBuffer.commit()
                }
            } else {
                Logger.log("setRenderTexture change size: \(texture.width) == \(camWidth), \(texture.height) == \(camHeight), \(width)")
                // Update the texture size
                recorder.disableRenderTexture()
                Task { @MainActor in
                    UniBridge.shared.updateRenderTexture([Int32(id), Int32(camWidth), Int32(camHeight)])
                }
            }
        }
    }

    func remove(id: Int32) {
        guard let recorder = recorders[id] else { return }
        recorder.stopRendering()
        recorders.removeValue(forKey: id)
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
