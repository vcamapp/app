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
    public internal(set) var subtitleObject: SceneObject?
    @ObservationIgnored private var loadGeneration = 0

    private init() {
        NotificationCenter.default.addObserver(
            forName: .screenResolutionDidChange,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                SceneObjectManager.shared.rasterizeTextForOutputSize()
            }
        }
    }

    /// Text is the one source rasterized for the pixels it occupies in the output; the others
    /// author their bitmap at their own resolution and are unaffected.
    private func rasterizeTextForOutputSize() {
        for object in objects {
            guard case .text = object.type else { continue }
            configure(object)
        }
        if let subtitleObject {
            configure(subtitleObject)
        }
    }

    public func object(byId id: Int32) -> SceneObject? {
        id == SceneObject.subtitleID ? subtitleObject : objects.find(byId: id)
    }

    public func add(_ object: SceneObject) {
        Logger.log("")
        configure(object)
        objects.append(object)
        persistScene()
    }

    /// The scene JSON stores the whole state, so a failed save only leaves the disk stale
    /// until the next successful one.
    private func persistScene() {
        do {
            try SceneManager.shared.saveCurrentSceneAndObjects()
        } catch {
            Logger.error(error)
        }
    }

    func configure(_ object: SceneObject) {
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

            let canvasSize = MainTexture.shared.canvasSize

            if image.size == .zero { // Migration from v0.6.3 and below & change the aspect ratio
                image.size = NSImage(contentsOf: image.url)?.size ?? .init(width: 800, height: 800)
                image.size = .init(width: image.size.width / canvasSize.width, height: image.size.height / canvasSize.height)
            }

            // The offset sentinel asks textureRect to place the object for the first time
            let region: CGRect = image.isPlaced
                ? .init(origin: .init(x: CGFloat(image.offset.x), y: CGFloat(image.offset.y)), size: image.size)
                : .init(origin: .zero, size: .invalid)
            let placement = addTexture(
                object.id,
                region: region,
                textureSize: .init(width: canvasSize.width * image.size.width, height: canvasSize.height * image.size.height)
            )
            image.offset = .init(x: Float(placement.origin.x), y: Float(placement.origin.y))
            image.size = placement.size
        case let .screen(screen):
            screen.region = addTexture(object.id, region: screen.region, crop: screen.crop, textureSize: screen.textureSize)
        case let .videoCapture(videoCapture):
            videoCapture.region = addTexture(object.id, region: videoCapture.region, crop: videoCapture.crop, textureSize: videoCapture.textureSize)
        case let .web(web):
            web.region = addTexture(object.id, region: web.region, crop: web.crop, textureSize: web.textureSize)
        case let .text(text):
            let canvasSize = MainTexture.shared.canvasSize
            if let renderer = RenderTextureManager.shared.textRenderer(id: object.id),
               let scale = TextObjectPlacement.scale(region: text.region, layoutSize: renderer.layoutSize) {
                renderer.setScale(display: scale, render: MainTexture.shared.renderScale)
            }
            let drawer = RenderTextureManager.shared.drawer(id: object.id)
            let textureSize = drawer?.size ?? .init(width: canvasSize.width * text.region.width, height: canvasSize.height * text.region.height)
            text.region = addTexture(object.id, region: text.region, textureSize: textureSize, allocationSize: drawer?.textureSize)
        case let .wind(wind):
            let direction = wind.direction
            let scale: Float = 100000 // Shift the digits by the number of significant figures to send as Int.
            UniBridge.shared.addWind([object.id, Int32(direction.x * scale), Int32(direction.y * scale), Int32(direction.z * scale)])
        }

        applyAvatarState(object)
    }

    /// The avatar is the one object the engine still owns, so its visibility and lock have to reach it.
    private func applyAvatarState(_ object: SceneObject) {
        guard case .avatar = object.type else { return }
        UniBridge.shared.avatarHidden(object.isHidden)
        UniBridge.shared.avatarLocked(object.isLocked)
    }

    /// Applies a geometry edit made on the canvas. Text re-rasterizes at its new size so that
    /// the glyphs stay crisp instead of a bitmap drawn for another size being scaled; the other
    /// types keep their texture as it is.
    public func didEditGeometry(_ object: SceneObject) {
        if case .text = object.type {
            configure(object)
        }
        persistScene()
    }

    /// Keeps the glyph scale and grows the object from the anchored edges, instead of refitting
    /// the text into the box it happened to have.
    func applyText(_ configuration: TextObjectConfiguration, to object: SceneObject, payload: SceneObject.Text, horizontal: TextObjectPlacement.HorizontalAnchor, vertical: TextObjectPlacement.VerticalAnchor) {
        guard let renderer = RenderTextureManager.shared.textRenderer(id: object.id) else { return }
        renderer.layout = .init(configuration: configuration, displayScale: renderer.layout.displayScale)
        payload.configuration = configuration
        payload.region = TextObjectPlacement.region(bitmapSize: renderer.size, anchoredTo: payload.region, horizontal: horizontal, vertical: vertical)
    }

    /// Re-registers the type-specific resources (image copies, render textures, wind, ...) that
    /// the object now points at.
    public func update(_ object: SceneObject) {
        configure(object)
        didChange(object)
    }

    /// Fits the object's texture geometry to the new source before re-registering it.
    public func replaceRenderer(_ renderer: any RenderTextureRenderer, of object: SceneObject) {
        guard let texture = object.type.croppableTexture else { return }
        RenderTextureManager.shared.set(renderer, id: object.id)
        texture.textureSize = renderer.size
        texture.region.size.scaleToFit(size: texture.textureSize)
        texture.crop = renderer.cropRect
        renderer.filter = texture.filter
        update(object)
    }

    /// The object types hold their state in reference types, so a change made through them stays
    /// invisible to Observation until it's pushed back here.
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

    /// Leaves the type-specific resources untouched, unlike `update(_:)`.
    private func updateState(_ id: Int32, _ change: (inout SceneObject) -> Void) {
        guard var object = objects.find(byId: id) else {
            return
        }
        change(&object)
        applyAvatarState(object)
        didChange(object)
    }

    /// The only definition of the rule: the object list, the delete key on the canvas and
    /// `remove` all defer to it.
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

        // Persist before touching any state, so that a failed save can't leave the saved scene
        // referencing the data files deleted below
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
        case .avatar: ()
        case .wind:
            UniBridge.shared.removeWind([object.id])
        case let .image(image):
            RenderTextureManager.shared.remove(id: object.id)
            VCamSceneDataStore(sceneId: SceneManager.shared.currentSceneId).removeManagedDataIfNeeded(at: image.url)
        case .screen, .videoCapture, .web, .text:
            RenderTextureManager.shared.remove(id: object.id)
        }
    }

    public func move(byId id: Int32, up: Bool) {
        Logger.log("\(id), \(up)")
        if objects.move(byId: id, up: up) {
            persistScene()
        }
    }

    public func moveToBack(id: Int32) {
        guard let index = objects.index(ofId: id) else {
            return
        }
        Logger.log("\(index)")

        let element = objects.remove(at: index)
        objects.insert(element, at: 0)
        persistScene()
    }

    public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        Logger.log("\(source), \(destination)")
        objects.move(fromOffsets: source, toOffset: destination)
        persistScene()
    }

    public func dispose() {
        UniBridge.shared.removeAllWinds()
        objects = objects.filter { $0.id == SceneObject.avatarID }
        // The subtitle's renderer goes with the rest, so it can't be left pointing at one
        subtitleObject = nil
        RenderTextureManager.shared.removeAll()
    }

    /// Returns the canvas-relative placement that `textureRect` decided, which the object stores
    /// as its own geometry. `allocationSize` is the texture's pixel size when it intentionally
    /// differs from the on-canvas size (a supersampled text); nil allocates at the displayed size
    private func addTexture(_ id: Int32, region: CGRect, crop: CGRect = .init(x: 0, y: 0, width: 1, height: 1), textureSize: CGSize, allocationSize: CGSize? = nil) -> CGRect {
        let canvasSize = MainTexture.shared.canvasSize
        let rect = textureRect(region: region, crop: crop, textureSize: textureSize)
        let allocation = allocationSize ?? rect.size
        RenderTextureManager.shared.allocateTexture(id: id, width: Int(allocation.width), height: Int(allocation.height))
        return CGRect(
            x: rect.origin.x / canvasSize.width,
            y: rect.origin.y / canvasSize.height,
            width: rect.width / canvasSize.width,
            height: rect.height / canvasSize.height
        )
    }

    /// The object's placement in canvas units, rounded to whole pixels as the texture is
    private func textureRect(region: CGRect, crop: CGRect, textureSize: CGSize) -> CGRect {
        let canvasSize = MainTexture.shared.canvasSize
        uniDebugLog("textureRect: r\(region), c\(crop), s\(canvasSize)")

        // The crop is a unit rect, so convert it to pixels to give fitSize the real aspect ratio
        let cropPixelSize = CGSize(width: crop.width * textureSize.width, height: crop.height * textureSize.height)
        let estimatedSize = fitSize(cropPixelSize, regionSize: region.size)

        return CGRect(
            x: (canvasSize.width * region.origin.x).rounded(.towardZero),
            y: (canvasSize.height * region.origin.y).rounded(.towardZero),
            width: estimatedSize.width.rounded(.towardZero),
            height: estimatedSize.height.rounded(.towardZero)
        )
    }

    private func fitSize(_ size: CGSize, regionSize: CGSize) -> CGSize {
        let canvasSize = MainTexture.shared.canvasSize

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
        UniBridge.shared.removeAllWinds()

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
                // Measured first, so the only rasterization happens at the stored region's size
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
        // The scene rebuild dropped every object, including the scene-independent subtitle
        SubtitleTextObject.reapply()
    }
}

extension SceneObjectManager {
    public func addImage(url: URL) {
        let renderer = ImageRenderer(imageURL: url, filter: nil)
        let id = RenderTextureManager.shared.add(renderer)
        let canvasSize = MainTexture.shared.canvasSize
        add(.init(id: id, type: .image(.init(url: url, size: .init(width: renderer.size.width / canvasSize.width, height: renderer.size.height / canvasSize.height), filter: nil)), isHidden: false, isLocked: false))
    }

    public func addScreenCapture(_ recorder: ScreenRecorder) {
        guard let config = recorder.captureConfig, let screenId = config.id else { return }
        let id = RenderTextureManager.shared.add(recorder)
        add(.init(id: id, type: .screen(.init(id: screenId, captureType: config.captureType.type, textureSize: recorder.size, crop: recorder.cropRect, filter: nil)), isHidden: false, isLocked: false))
    }

    public func addText(_ configuration: TextObjectConfiguration) {
        // Glyphs start at a fixed size so that the text reads the same whatever its length;
        // the user scales the object from there
        let renderer = TextRenderer(layout: .init(configuration: configuration, displayScale: TextObjectPlacement.fittedDefaultScale(of: configuration)))
        let id = RenderTextureManager.shared.add(renderer)
        let region = CGRect(origin: .zero, size: renderer.size / MainTexture.shared.canvasSize)
        add(.init(id: id, type: .text(.init(configuration: configuration, region: region)), isHidden: false, isLocked: false))
    }

    public func addVideoCapture(_ drawer: CaptureDeviceRenderer) {
        let id = RenderTextureManager.shared.add(drawer)
        add(.init(id: id, type: .videoCapture(.init(id: drawer.id, textureSize: drawer.size, crop: drawer.cropRect, filter: nil)), isHidden: false, isLocked: false))
    }
}

extension SceneObjectManager {
    /// Nothing is shared with the original, so editing or removing either copy leaves the other
    /// one as it was.
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
