import SwiftUI
import VCamBridge
import VCamLogger

@MainActor
public final class RenderTextureManager {
    public static let shared = RenderTextureManager()

    private var recorders: [Int32: any RenderTextureRenderer] = [:]
    private var textures: [Int32: any MTLTexture] = [:]
    /// A new texture holds whatever its memory last held, often the texture of an object the
    /// previous scene freed, and the compositor reads it from another command queue. So it is
    /// published only once its first write has completed on the GPU.
    private var unwrittenTextures: [Int32: any MTLTexture] = [:]
    private var staticTextureWaiters: [UUID: CheckedContinuation<Void, Never>] = [:]
    /// Renderers whose pixels outgrew the texture on screen, until a texture of the new size is written
    private var pendingResizes: Set<Int32> = []
    /// Where the texture on screen was drawn before its content changed, see `holdPlacement`
    private var heldPlacements: [Int32: CGRect] = [:]
    private let mtlDevice = MTLCreateSystemDefaultDevice()!
    // Streaming inputs differ every frame, so intermediate caching only wastes memory
    private lazy var ciContext = CIContext(mtlDevice: mtlDevice, options: [.cacheIntermediates: false, .name: "RenderTextureManager"])
    private lazy var commandQueue = mtlDevice.makeCommandQueue()!

    public func add(_ recorder: any RenderTextureRenderer) -> Int32 {
        let id = Int32.random(in: 0..<Int32.max)
        set(recorder, id: id)
        return id
    }

    public func set(_ recorder: any RenderTextureRenderer, id: Int32) {
        uniDebugLog("Set rendertexture: \(id)")
        // The draw callback and the renderer retain each other until it stops, and a replaced
        // renderer would otherwise keep capturing into the same texture
        if let replaced = recorders[id], replaced !== recorder {
            replaced.stopRendering()
        }
        recorders[id] = recorder
    }

    public func drawer(id: Int32) -> (any RenderTextureRenderer)? {
        recorders[id]
    }

    /// Holds what Core Image writes: sRGB-encoded color, premultiplied in that encoding.
    /// A plain format, so that a reader gets those values to unpremultiply before decoding them
    public func texture(id: Int32) -> (any MTLTexture)? {
        textures[id]
    }

    /// A new content decides its placement before its pixels exist, and the previous texture stays
    /// on screen until they are written. Drawn at the new placement, that texture would squeeze or
    /// stretch the old content (a longer text shrunk into a shorter one's box), so it keeps the
    /// placement it was drawn at until then. A rescale needs no hold: the same content stretched
    /// to the new size is what it is about to become.
    func holdPlacement(_ placement: CGRect, id: Int32) {
        guard pendingResizes.contains(id), heldPlacements[id] == nil else { return }
        heldPlacements[id] = placement
    }

    /// The canvas-relative placement to draw the texture at instead of the object's own
    public func heldPlacement(id: Int32) -> CGRect? {
        heldPlacements[id]
    }

    private func finishResize(id: Int32) {
        pendingResizes.remove(id)
        heldPlacements.removeValue(forKey: id)
    }

    func textRenderer(id: Int32) -> TextRenderer? {
        guard let renderer = recorders[id] as? TextRenderer, renderer.size.width > 0 else { return nil }
        return renderer
    }

    /// An existing texture of the same size is reused, and a resized one keeps showing the
    /// previous texture until it is written, so that the object does not blink.
    public func allocateTexture(id: Int32, width: Int, height: Int) {
        let width = max(width, 1)
        let height = max(height, 1)
        if let texture = unwrittenTextures[id] ?? textures[id], texture.width == width, texture.height == height {
            setRenderTexture(texture, id: id)
            if unwrittenTextures[id] == nil {
                // Written in place into the texture on screen
                finishResize(id: id)
            }
            return
        }
        let wantsMipmap = recorders[id]?.isStaticSource ?? false
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: wantsMipmap
        )
        // renderTarget only for the blit that regenerates the mipmaps
        descriptor.usage = wantsMipmap ? [.shaderRead, .shaderWrite, .renderTarget] : [.shaderRead, .shaderWrite]
        descriptor.storageMode = .private
        guard let texture = mtlDevice.makeTexture(descriptor: descriptor) else {
            Logger.log("failed to allocate \(width)x\(height) for \(id)")
            finishResize(id: id)
            return
        }
        unwrittenTextures[id] = texture
        setRenderTexture(texture, id: id)
    }

    private func publishWrittenTexture(_ written: ObjectIdentifier, id: Int32) {
        guard let texture = unwrittenTextures[id], ObjectIdentifier(texture) == written else { return }
        unwrittenTextures.removeValue(forKey: id)
        textures[id] = texture
        finishResize(id: id)
        resumeStaticTextureWaitersIfWritten()
    }

    /// Images and texts each finish writing in their own frame, so a scene shown before they all
    /// have would reveal what an object in front of them is meant to cover.
    /// Streams are not waited for, as their first frame comes whenever the source delivers it.
    func waitForStaticTextures(timeout: Duration) async {
        guard hasUnwrittenStaticTexture else { return }
        let waiter = UUID()
        // A source that never writes must not keep the scene from showing
        let timer = Task {
            try? await Task.sleep(for: timeout)
            staticTextureWaiters.removeValue(forKey: waiter)?.resume()
        }
        await withCheckedContinuation { staticTextureWaiters[waiter] = $0 }
        timer.cancel()
    }

    private var hasUnwrittenStaticTexture: Bool {
        unwrittenTextures.keys.contains { recorders[$0]?.isStaticSource == true }
    }

    private func resumeStaticTextureWaitersIfWritten() {
        guard !hasUnwrittenStaticTexture else { return }
        let waiters = staticTextureWaiters.values
        staticTextureWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }

    private func setRenderTexture(_ texture: any MTLTexture, id: Int32) {
        uniDebugLog("setRenderTexture: \(id) in \(recorders.keys)")
        guard let recorder = recorders[id] else {
            uniDebugLog("setRenderTexture: no recorder \(id)")
            return
        }
        Logger.log("\(texture.width)x\(texture.height), \(type(of: recorder))")

        let targetWidth = texture.width
        let targetHeight = texture.height
        let hasMipmaps = texture.mipmapLevelCount > 1

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
                guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
                ciContext.render(croppedImage, to: texture, commandBuffer: commandBuffer, bounds: croppedImage.extent, colorSpace: .sRGB)
                // Core Image only writes the base level, so the blit rides the same command buffer
                // to stay ordered
                if hasMipmaps, let blit = commandBuffer.makeBlitCommandEncoder() {
                    blit.generateMipmaps(for: texture)
                    blit.endEncoding()
                }
                if unwrittenTextures[id] === texture {
                    let written = ObjectIdentifier(texture)
                    commandBuffer.addCompletedHandler { _ in
                        Task { @MainActor in
                            self.publishWrittenTexture(written, id: id)
                        }
                    }
                }
                commandBuffer.commit()
            } else {
                Logger.log("setRenderTexture change size: \(targetWidth) == \(camWidth), \(targetHeight) == \(camHeight), \(width)")
                pendingResizes.insert(id)
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
        unwrittenTextures.removeValue(forKey: id)
        finishResize(id: id)
        resumeStaticTextureWaitersIfWritten()
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
