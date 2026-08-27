import SwiftUI
import VCamEntity
import VCamBridge
import VCamControl
import VCamData
import VCamLogger
import AVFoundation
import ScreenCaptureKit

@MainActor
@Observable
public final class SceneObjectManager {
    public static let shared = SceneObjectManager()

    public var objects: [SceneObject] = VCamSceneDataStore.defaultObjects
    /// The subtitle overlays every scene, so it is kept out of the scene's object list.
    /// Only SubtitleTextObject maintains it.
    public internal(set) var subtitleObject: SceneObject?
    @ObservationIgnored private var loadGeneration = 0

    /// Finds a scene object or the scene-independent subtitle by the id the engine uses
    public func object(byId id: Int32) -> SceneObject? {
        id == SceneObject.subtitleID ? subtitleObject : objects.find(byId: id)
    }

    public func add(_ object: SceneObject) {
        Logger.log("")
        configure(object)
        objects.append(object)
        persistScene()
    }

    /// The scene JSON stores the whole state, so a failed save here only leaves the disk
    /// stale until the next successful save; the in-memory state stays consistent.
    private func persistScene() {
        do {
            try SceneManager.shared.saveCurrentSceneAndObjects()
        } catch {
            Logger.error(error)
        }
    }

    func configure(_ object: SceneObject) {
        let uniBridge = UniBridge.shared
        uniDebugLog("SceneObjectManager.configure: \(object)")
        switch object.type {
        case .avatar: ()
        case let .image(image):
            let sceneId = SceneManager.shared.currentSceneId
            do {
                image.url = try VCamSceneDataStore(sceneId: sceneId).copyData(fromURL: image.url)
            } catch {
                // Keep referencing the source file so that the object still renders in this session
                Logger.error(error)
            }

            let canvasSize = uniBridge.canvasCGSize

            if image.size == .zero { // Migration from v0.6.3 and below & change the aspect ratio
                image.size = NSImage(contentsOf: image.url)?.size ?? .init(width: 800, height: 800)
                image.size = .init(width: image.size.width / canvasSize.width, height: image.size.height / canvasSize.height)
            }

            // The offset sentinel asks textureRect to place the object for the first time
            let region: CGRect = image.isPlaced
                ? .init(origin: .init(x: CGFloat(image.offset.x), y: CGFloat(image.offset.y)), size: image.size)
                : .init(origin: .zero, size: .invalid)
            let placement = addFixedTexture(
                object.id,
                type: .photo,
                region: region,
                textureSize: .init(width: canvasSize.width * image.size.width, height: canvasSize.height * image.size.height)
            )
            image.offset = .init(x: Float(placement.origin.x), y: Float(placement.origin.y))
            image.size = placement.size
        case let .screen(screen):
            let rect = textureRect(region: screen.region, crop: screen.crop, textureSize: screen.textureSize)
            uniBridge.addRenderTexture([object.id, RenderTextureType.screen.rawValue, rect[2], rect[3]] + rect)
        case let .videoCapture(videoCapture):
            let rect = textureRect(region: videoCapture.region, crop: videoCapture.crop, textureSize: videoCapture.textureSize)
            uniBridge.addRenderTexture([object.id, RenderTextureType.captureDevice.rawValue, rect[2], rect[3]] + rect)
        case let .web(web):
            let rect = textureRect(region: web.region, crop: web.crop, textureSize: web.textureSize)
            uniBridge.addRenderTexture([object.id, RenderTextureType.web.rawValue, rect[2], rect[3]] + rect)
        case let .text(text):
            let canvasSize = uniBridge.canvasCGSize
            if let renderer = RenderTextureManager.shared.textRenderer(id: object.id),
               let scale = TextObjectPlacement.scale(region: text.region, layoutSize: renderer.layoutSize) {
                // Rasterize at the size the object is drawn at. This is where a resize made on
                // the canvas, or a scene reloaded at another resolution, reaches the renderer.
                renderer.setDisplayScale(scale)
            }
            let drawer = RenderTextureManager.shared.drawer(id: object.id)
            let textureSize = drawer?.size ?? .init(width: canvasSize.width * text.region.width, height: canvasSize.height * text.region.height)
            text.region = addFixedTexture(object.id, type: .text, region: text.region, textureSize: textureSize, allocationSize: drawer?.textureSize)
        case let .wind(wind):
            let direction = wind.direction
            let scale: Float = 100000 // Shift the digits by the number of significant figures to send as Int.
            uniBridge.addWind([object.id, Int32(direction.x * scale), Int32(direction.y * scale), Int32(direction.z * scale)])
        }

        applyState(object)
    }

    func applyState(_ object: SceneObject) {
        let uniBridge = UniBridge.shared
        uniBridge.setObjectActive([object.id, object.isHidden ? 0 : 1])
        uniBridge.setObjectLocked([object.id, object.isLocked ? 1 : 0])
    }

    /// Re-registers an object whose geometry the engine just changed. Text re-rasterizes at
    /// its new size, so the glyphs stay crisp instead of a bitmap drawn for another size
    /// being scaled; the other types keep their texture as it is.
    public func didResize(_ object: SceneObject) {
        guard case .text = object.type else { return }
        configure(object)
    }

    /// Re-renders a text object with an edited configuration, keeping the glyph scale it is
    /// drawn at and growing it from the edges its anchors name, instead of refitting the
    /// text into the box it happened to have.
    func applyText(_ configuration: TextObjectConfiguration, to object: SceneObject, payload: SceneObject.Text, horizontal: TextObjectPlacement.HorizontalAnchor, vertical: TextObjectPlacement.VerticalAnchor) {
        guard let renderer = RenderTextureManager.shared.textRenderer(id: object.id) else { return }
        renderer.layout = .init(configuration: configuration, displayScale: renderer.layout.displayScale)
        payload.configuration = configuration
        payload.region = TextObjectPlacement.region(bitmapSize: renderer.size, anchoredTo: payload.region, horizontal: horizontal, vertical: vertical)
    }

    /// Re-registers the type-specific resources (image copies, render textures, wind, ...)
    /// because the object now points at different data.
    public func update(_ object: SceneObject) {
        configure(object)
        didChange(object)
    }

    /// Swaps in a renderer the user has just reconfigured, and fits the object's
    /// texture geometry to the new source before re-registering it.
    public func replaceRenderer(_ renderer: any RenderTextureRenderer, of object: SceneObject) {
        guard let texture = object.type.croppableTexture else { return }
        RenderTextureManager.shared.set(renderer, id: object.id)
        texture.textureSize = renderer.size
        texture.region.size.scaleToFit(size: texture.textureSize)
        texture.crop = renderer.cropRect
        renderer.filter = texture.filter
        update(object)
    }

    /// Persists a change and notifies Observation. The object types hold their state in
    /// reference types, so a change made through them stays invisible until it's pushed back here.
    public func didChange(_ object: SceneObject) {
        objects.update(object)
        persistScene()
    }

    public func setHidden(_ isHidden: Bool, id: Int32) {
        updateState(id) { $0.isHidden = isHidden }
    }

    public func setLocked(_ isLocked: Bool, id: Int32) {
        updateState(id) { $0.isLocked = isLocked }
    }

    /// Applies a change that only affects the object's own state, so the type-specific
    /// resources are left untouched.
    private func updateState(_ id: Int32, _ change: (inout SceneObject) -> Void) {
        guard var object = objects.find(byId: id) else {
            return
        }
        change(&object)
        applyState(object)
        didChange(object)
    }

    /// Whether the user may delete the object. This is the only definition of the rule: the
    /// object list disables its button on it, the engine asks before the delete key destroys
    /// anything, and `remove` refuses anything it rejects.
    public func canRemove(byId id: Int32) -> Bool {
        switch id {
        case SceneObject.avatarID: false // The avatar is what the scene is built around
        case SceneObject.subtitleID: false // The subtitle is removed by clearing its text
        default: true
        }
    }

    public func remove(byId id: Int32) {
        // The subtitle is not in `objects`, so it can't be reached from here
        guard let object = objects.find(byId: id) else {
            return
        }
        remove(object)
    }

    private func remove(_ object: SceneObject) {
        Logger.log("\(object.type)")
        guard canRemove(byId: object.id) else { return }

        // Persist the removal before touching any state so that a failed save can't
        // leave the saved scene referencing data files deleted below
        var newObjects = objects
        newObjects.remove(byId: object.id)
        do {
            try SceneManager.shared.saveCurrentScene(objects: newObjects)
        } catch {
            Logger.error(error)
            return
        }
        objects = newObjects

        switch object.type {
        case .avatar, .wind: ()
        case let .image(image):
            RenderTextureManager.shared.remove(id: object.id)
            VCamSceneDataStore(sceneId: SceneManager.shared.currentSceneId).removeManagedDataIfNeeded(at: image.url)
        case .screen, .videoCapture, .web, .text:
            RenderTextureManager.shared.remove(id: object.id)
        }
        deleteFromEngine(id: object.id)
    }

    /// The engine deletes the currently selected item, so the target has to be selected
    /// first; otherwise removing an unselected object leaves it on screen.
    func deleteFromEngine(id: Int32) {
        UniBridge.shared.objectSelected.wrappedValue = id
        UniBridge.shared.deleteObject()
    }

    public func move(byId id: Int32, up: Bool) {
        Logger.log("\(id), \(up)")
        if objects.move(byId: id, up: up) {
            updateObjectOrder()
        }
    }

    public func moveToBack(id: Int32) {
        guard let index = objects.index(ofId: id) else {
            return
        }
        Logger.log("\(index)")

        let element = objects.remove(at: index)
        objects.insert(element, at: 0)
        updateObjectOrder()
    }

    public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        Logger.log("\(source), \(destination)")
        objects.move(fromOffsets: source, toOffset: destination)
        updateObjectOrder()
    }

    func updateObjectOrder(persist: Bool = true) {
        // The subtitle sits in front of the scene's objects
        UniBridge.shared.updateObjectOrder(objects.map(\.id) + (subtitleObject.map { [$0.id] } ?? []) + [-1])
        if persist {
            persistScene()
        }
    }

    public func dispose() {
        objects = objects.filter { $0.id == SceneObject.avatarID }
        // The subtitle's renderer goes with the rest, so it can't be left pointing at one
        subtitleObject = nil
        RenderTextureManager.shared.removeAll()
    }

    /// Registers an uncropped texture and returns the canvas-relative placement
    /// textureRect decided, which the object stores as its own geometry.
    @discardableResult
    /// `allocationSize` is the texture's pixel size when it intentionally differs from the
    /// on-canvas size (a supersampled text); nil allocates at the displayed size
    private func addFixedTexture(_ id: Int32, type: RenderTextureType, region: CGRect, textureSize: CGSize, allocationSize: CGSize? = nil) -> CGRect {
        let canvasSize = UniBridge.shared.canvasCGSize
        let rect = textureRect(region: region, crop: .init(x: 0, y: 0, width: 1, height: 1), textureSize: textureSize)
        let allocation = allocationSize.map { [Int32($0.width), Int32($0.height)] } ?? [rect[2], rect[3]]
        UniBridge.shared.addRenderTexture([id, type.rawValue] + allocation + rect)
        return .init(
            x: CGFloat(rect[0]) / canvasSize.width,
            y: CGFloat(rect[1]) / canvasSize.height,
            width: CGFloat(rect[2]) / canvasSize.width,
            height: CGFloat(rect[3]) / canvasSize.height
        )
    }

    private func textureRect(region: CGRect, crop: CGRect, textureSize: CGSize) -> [Int32] {
        let canvasSize = UniBridge.shared.canvasCGSize
        uniDebugLog("textureRect: r\(region), c\(crop), s\(canvasSize)")
        let x = Int32(canvasSize.width * region.origin.x)
        let y = Int32(canvasSize.height * region.origin.y)

        // The crop is a unit rect, so convert it to pixels to give fitSize the real aspect ratio
        let cropPixelSize = CGSize(width: crop.width * textureSize.width, height: crop.height * textureSize.height)
        let estimatedSize = fitSize(cropPixelSize, regionSize: region.size)

        return [x, y, Int32(estimatedSize.width), Int32(estimatedSize.height)]
    }

    private func fitSize(_ size: CGSize, regionSize: CGSize) -> CGSize {
        let canvasSize = UniBridge.shared.canvasCGSize

        var estimatedWidth: CGFloat

        if regionSize.width < 0 { // Can't compare with .invalid, so determine based on whether it's less than 0
            // Initially, display at 80% relative to the canvas to fit within the screen.
            if size.width > size.height {
                estimatedWidth = canvasSize.width * 0.8
            } else {
                let height = canvasSize.height * 0.8
                estimatedWidth = height * size.width / size.height
            }
        } else {
            estimatedWidth = canvasSize.width * regionSize.width
        }
        return .init(width: estimatedWidth, height: estimatedWidth * size.height / size.width)
    }
}

extension SceneObjectManager {
    func loadObjects(_ scene: VCamScene) async {
        // Abandon this load when a newer one starts while awaiting screen capture creation
        loadGeneration &+= 1
        let generation = loadGeneration

        let dataStore = VCamSceneDataStore(sceneId: scene.id)

        RenderTextureManager.shared.removeAll()
        UniBridge.shared.resetAllObjects()

        self.objects = []
        var availableContent: SCShareableContent?
        var availableContentError: (any Error)?

        for object in scene.objects {
            let sceneObject = object.sceneObject(dataStore: dataStore)
            switch object.type {
            case let .avatar(avatar):
                Logger.log("load avatar \(avatar == .zero)")
                if avatar == .zero {
                    CameraControl.resetCamera()
                } else {
                    UniBridge.shared.objectAvatarTransform([
                        avatar.position.x, avatar.position.y, avatar.position.z,
                        avatar.rotation.x, avatar.rotation.y, avatar.rotation.z,
                    ])
                }
            case .image:
                if case let .image(image) = sceneObject.type {
                    let renderer = ImageRenderer(imageURL: image.url, filter: image.filter)
                    RenderTextureManager.shared.set(renderer, id: object.id)
                    configure(sceneObject)
                }
            case let .screen(id, state):
                do {
                    if availableContent == nil, availableContentError == nil {
                        do {
                            availableContent = try await ScreenRecorder.availableContent()
                        } catch {
                            availableContentError = error
                        }
                    }
                    if let availableContentError {
                        throw availableContentError
                    }
                    guard let availableContent else { continue }
                    let recorder = try await ScreenRecorder.create(
                        id: id,
                        screenCapture: state,
                        availableContent: availableContent
                    )
                    guard generation == loadGeneration else { return }
                    recorder.filter = state.texture.filter.map(ImageFilter.init(configuration:))
                    RenderTextureManager.shared.set(recorder, id: object.id)
                    configure(sceneObject)
                } catch {
                    guard generation == loadGeneration else { return }
                    Logger.log("Failed to create ScreenRecorder: \(error.localizedDescription)")
                }
            case let .captureDevice(uniqueID, state):
                if let device = AVCaptureDevice(uniqueID: uniqueID),
                   let drawer = try? CaptureDeviceRenderer(device: device, cropRect: state.crop.rect) {
                    drawer.filter = state.filter.map(ImageFilter.init(configuration:))
                    RenderTextureManager.shared.set(drawer, id: object.id)
                }
                configure(sceneObject)
            case .web:
                if case let .web(web) = sceneObject.type {
                    let renderer = WebRenderer(
                        resource: .init(web: web),
                        size: web.textureSize,
                        fps: web.fps,
                        css: web.css,
                        js: web.js
                    )
                    renderer.filter = web.filter
                    RenderTextureManager.shared.set(renderer, id: object.id)
                    configure(sceneObject)
                }
            case let .text(state):
                // Measured first, so the only rasterization happens at the size the stored
                // region draws the object at
                let scale = TextObjectPlacement.scale(region: state.region.rect, layoutSize: TextRenderer.measure(state.configuration))
                    ?? TextObjectPlacement.fittedDefaultScale(of: state.configuration)
                RenderTextureManager.shared.set(TextRenderer(layout: .init(configuration: state.configuration, displayScale: scale)), id: object.id)
                configure(sceneObject)
            case .wind:
                configure(sceneObject)
            }
            objects.append(sceneObject)
        }

        Logger.log("finish loadObjects")
        // Loading a scene must not implicitly save it, so only notify the order to the engine
        updateObjectOrder(persist: false)
        // The scene rebuild wiped every engine object, including the scene-independent subtitle
        SubtitleTextObject.reapply()
    }
}

extension SceneObjectManager {
    public func addImage(url: URL) {
        let renderer = ImageRenderer(imageURL: url, filter: nil)
        let id = RenderTextureManager.shared.add(renderer)
        let canvasSize = UniBridge.shared.canvasCGSize
        add(.init(id: id, type: .image(.init(url: url, size: .init(width: renderer.size.width / canvasSize.width, height: renderer.size.height / canvasSize.height), filter: nil)), isHidden: false, isLocked: false))
    }

    public func addScreenCapture(_ recorder: ScreenRecorder) {
        guard let config = recorder.captureConfig, let screenId = config.id else { return }
        let id = RenderTextureManager.shared.add(recorder)
        add(.init(id: id, type: .screen(.init(id: screenId, captureType: config.captureType.type, textureSize: recorder.size, crop: recorder.cropRect, filter: nil)), isHidden: false, isLocked: false))
    }

    public func addText(_ configuration: TextObjectConfiguration) {
        // Glyphs start at a fixed size regardless of how much was typed, so that the text
        // reads the same whatever its length; the user scales the object from there
        let renderer = TextRenderer(layout: .init(configuration: configuration, displayScale: TextObjectPlacement.fittedDefaultScale(of: configuration)))
        let id = RenderTextureManager.shared.add(renderer)
        let region = CGRect(origin: .zero, size: renderer.size / UniBridge.shared.canvasCGSize)
        add(.init(id: id, type: .text(.init(configuration: configuration, region: region)), isHidden: false, isLocked: false))
    }

    public func addVideoCapture(_ drawer: CaptureDeviceRenderer) {
        let id = RenderTextureManager.shared.add(drawer)
        add(.init(id: id, type: .videoCapture(.init(id: drawer.id, textureSize: drawer.size, crop: drawer.cropRect, filter: nil)), isHidden: false, isLocked: false))
    }
}

extension SceneObjectManager {
    /// Adds a copy at the same place on the canvas. Nothing is shared with the original, so
    /// editing or removing either copy leaves the other one as it was.
    public func duplicate(_ object: SceneObject) async {
        guard let duplicated = await makeDuplicate(of: object) else { return }
        add(duplicated)
    }

    private func makeDuplicate(of object: SceneObject) async -> SceneObject? {
        func copy(id: Int32 = .random(in: 0..<Int32.max), type: SceneObject.ObjectType) -> SceneObject {
            .init(id: id, type: type, name: object.name, isHidden: object.isHidden, isLocked: object.isLocked)
        }

        let renderTextureManager = RenderTextureManager.shared
        do {
            switch object.type {
            case .avatar:
                // The avatar is what the scene is built around, so there is only ever one of it
                return nil
            case let .image(image):
                let url = try VCamSceneDataStore(sceneId: SceneManager.shared.currentSceneId).duplicateData(at: image.url)
                let id = renderTextureManager.add(ImageRenderer(imageURL: url, filter: image.filter))
                return copy(id: id, type: .image(.init(url: url, offset: image.offset, size: image.size, filter: image.filter)))
            case let .screen(screen):
                let recorder = try await ScreenRecorder.create(id: screen.id, screenCapture: .init(
                    captureType: screen.captureType,
                    texture: .init(
                        width: Float(screen.textureSize.width),
                        height: Float(screen.textureSize.height),
                        region: .init(rect: screen.region),
                        crop: .init(rect: screen.crop),
                        filter: screen.filter?.configuration
                    )
                ))
                let id = renderTextureManager.add(recorder)
                return copy(id: id, type: .screen(.init(id: screen.id, captureType: screen.captureType, textureSize: screen.textureSize, region: screen.region, crop: screen.crop, filter: screen.filter)))
            case let .videoCapture(videoCapture):
                let device = try AVCaptureDevice(uniqueID: videoCapture.id).orThrow(NSError.vcam(message: "duplicate:capture device not found"))
                let renderer = try CaptureDeviceRenderer(device: device, cropRect: videoCapture.crop)
                renderer.filter = videoCapture.filter
                let id = renderTextureManager.add(renderer)
                return copy(id: id, type: .videoCapture(.init(id: videoCapture.id, textureSize: videoCapture.textureSize, region: videoCapture.region, crop: videoCapture.crop, filter: videoCapture.filter)))
            case let .web(web):
                let renderer = WebRenderer(resource: .init(web: web), size: web.textureSize, fps: web.fps, css: web.css, js: web.js)
                renderer.filter = web.filter
                let id = renderTextureManager.add(renderer)
                return copy(id: id, type: .web(.init(url: web.url, path: web.path, fps: web.fps, css: web.css, js: web.js, textureSize: web.textureSize, region: web.region, crop: web.crop, filter: web.filter)))
            case let .text(text):
                // Rasterized at the original's scale so that the copy's glyphs look the same
                let displayScale = renderTextureManager.textRenderer(id: object.id)?.layout.displayScale
                    ?? TextObjectPlacement.fittedDefaultScale(of: text.configuration)
                let id = renderTextureManager.add(TextRenderer(layout: .init(configuration: text.configuration, displayScale: displayScale)))
                return copy(id: id, type: .text(.init(configuration: text.configuration, region: text.region)))
            case let .wind(wind):
                return copy(type: .wind(.init(direction: wind.direction)))
            }
        } catch {
            Logger.error(error)
            return nil
        }
    }
}
