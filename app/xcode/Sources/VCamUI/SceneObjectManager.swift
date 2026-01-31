import SwiftUI
import VCamEntity
import VCamLocalization
import VCamBridge
import VCamData
import VCamLogger
import AVFoundation

@MainActor
@Observable
public final class SceneObjectManager {
    public static let shared = SceneObjectManager()

    public var objects: [SceneObject] = VCamSceneDataStore.defaultObjects

    public func add(_ object: SceneObject) {
        Logger.log("")
        configure(object)
        objects.append(object)
        try? SceneManager.shared.saveCurrentSceneAndObjects()
    }

    private func configure(_ object: SceneObject) {
        let uniBridge = UniBridge.shared
        uniDebugLog("SceneObjectManager.configure: \(object)")
        switch object.type {
        case .avatar: ()
        case let .image(image):
            let sceneId = SceneManager.shared.currentSceneId
            image.url = VCamSceneDataStore(sceneId: sceneId).copyData(fromURL: image.url)

            let canvasSize = uniBridge.canvasCGSize

            if image.size == .zero { // Migration from v0.6.3 and below & change the aspect ratio
                image.size = NSImage(contentsOf: image.url)?.size ?? .init(width: 800, height: 800)
                image.size = .init(width: image.size.width / canvasSize.width, height: image.size.height / canvasSize.height)
            }

            let region: CGRect
            if image.offset.x < -1000 { // Set the initial position to be dependent on textureRect
                region = .init(origin: .zero, size: .invalid)
            } else {
                region = .init(origin: .init(x: CGFloat(image.offset.x), y: CGFloat(image.offset.y)), size: image.size)
            }

            let rect = textureRect(region: region, crop: .init(x: 0, y: 0, width: 1, height: canvasSize.height * image.size.height / (canvasSize.width * image.size.width)))
            image.offset = .init(x: Float(rect[0]) / Float(canvasSize.width), y: Float(rect[1]) / Float(canvasSize.height))
            image.size = .init(width: CGFloat(rect[2]) / canvasSize.width, height: CGFloat(rect[3]) / canvasSize.height)
            uniBridge.addRenderTexture([object.id, RenderTextureType.photo.rawValue, rect[2], rect[3]] + rect)
        case let .screen(screen):
            let rect = textureRect(region: screen.region, crop: screen.crop)
            uniBridge.addRenderTexture([object.id, RenderTextureType.screen.rawValue, rect[2], rect[3]] + rect)
        case let .videoCapture(videoCapture):
            let rect = textureRect(region: videoCapture.region, crop: videoCapture.crop)
            uniBridge.addRenderTexture([object.id, RenderTextureType.captureDevice.rawValue, rect[2], rect[3]] + rect)
        case let .web(web):
            let rect = textureRect(region: web.region, crop: web.crop)
            uniBridge.addRenderTexture([object.id, RenderTextureType.web.rawValue, rect[2], rect[3]] + rect)
        case let .wind(wind):
            let direction = wind.direction
            let scale: Float = 100000 // Shift the digits by the number of significant figures to send as Int.
            uniBridge.addWind([object.id, Int32(direction.x * scale), Int32(direction.y * scale), Int32(direction.z * scale)])
        }

        uniBridge.setObjectActive([object.id, object.isHidden ? 0 : 1])
        uniBridge.setObjectLocked([object.id, object.isLocked ? 1 : 0])
    }

    public func update(_ object: SceneObject) {
        objects.update(object)
        configure(object)
        try? SceneManager.shared.saveCurrentSceneAndObjects()
    }

    func remove(byIndex index: Int) {
        remove(objects[index])
    }

    public func remove(byId id: Int32) {
        guard let object = objects.find(byId: id) else {
            return
        }
        remove(object)
    }

    private func remove(_ object: SceneObject) {
        Logger.log("\(object.type)")
        switch object.type {
        case .avatar:
            return
        case .wind: ()
        case let .image(image):
            try? FileManager.default.removeItem(at: image.url)
            RenderTextureManager.shared.remove(id: object.id)
        case .screen, .videoCapture, .web:
            RenderTextureManager.shared.remove(id: object.id)
        }
        objects.remove(byId: object.id)
        UniBridge.shared.deleteObject()
        try? SceneManager.shared.saveCurrentSceneAndObjects()
    }

    public func move(byId id: Int32, up: Bool) {
        guard let index = objects.index(ofId: id) else {
            return
        }
        Logger.log("\(id), \(up), \(index)")

        let destination = index + (up ? 1 : -1)
        if 0 <= destination && destination < objects.count {
            objects.swapAt(index, destination)
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

    func updateObjectOrder() {
        UniBridge.shared.updateObjectOrder(SceneObjectManager.shared.objects.map(\.id) + [-1])
        try? SceneManager.shared.saveCurrentSceneAndObjects()
    }

    public func didChangeObjects() {
        self.objects = objects
    }

    public func dispose() {
        objects = objects.filter { $0.id == SceneObject.avatarID }
        RenderTextureManager.shared.removeAll()
    }

    private func textureRect(region: CGRect, crop: CGRect) -> [Int32] {
        let canvasSize = UniBridge.shared.canvasCGSize
        uniDebugLog("textureRect: r\(region), c\(crop), s\(canvasSize)")
        let x = Int32(canvasSize.width * region.origin.x)
        let y = Int32(canvasSize.height * region.origin.y)

        let estimatedWidth = fitSize(crop.size, regionSize: region.size).width
        let estimatedHeight = estimatedWidth * crop.size.height / crop.size.width

        return [x, y, Int32(estimatedWidth), Int32(estimatedHeight)]
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
    func loadObjects(_ scene: VCamScene) {
        let dataStore = VCamSceneDataStore(sceneId: scene.id)

        RenderTextureManager.shared.removeAll()
        UniBridge.shared.resetAllObjects()

        self.objects = []

        let group = DispatchGroup()
        scene.objects.forEach { _ in group.enter() }

        for object in scene.objects {
            let sceneObject = object.sceneObject(dataStore: dataStore)
            switch object.type {
            case let .avatar(avatar):
                Logger.log("load avatar \(avatar == .zero)")
                if avatar == .zero {
                    UniBridge.shared.resetCamera()
                } else {
                    UniBridge.shared.objectAvatarTransform([
                        avatar.position.x, avatar.position.y, avatar.position.z,
                        avatar.rotation.x, avatar.rotation.y, avatar.rotation.z,
                    ])
                }
                group.leave()
            case .image:
                if case let .image(image) = sceneObject.type {
                    let renderer = ImageRenderer(imageURL: image.url, filter: image.filter)
                    RenderTextureManager.shared.set(renderer, id: object.id)
                    configure(sceneObject)
                }
                group.leave()
            case let .screen(id, state):
                ScreenRecorder.create(id: id, screenCapture: state) { recorder in
                    recorder.filter = state.texture.filter.map(ImageFilter.init(configuration:))
                    RenderTextureManager.shared.set(recorder, id: object.id)
                    self.configure(sceneObject)
                    group.leave()
                }
            case let .captureDevice(uniqueID, state):
                if let device = AVCaptureDevice(uniqueID: uniqueID),
                   let drawer = try? CaptureDeviceRenderer(device: device, cropRect: state.crop.rect) {
                    drawer.filter = state.filter.map(ImageFilter.init(configuration:))
                    RenderTextureManager.shared.set(drawer, id: object.id)
                }
                configure(sceneObject)
                group.leave()
            case let .web(state):
                let renderer = WebRenderer(resource: state.url != nil ? .url(state.url!) : .path(bookmark: state.path ?? .init()), size: state.texture.textureSize, fps: state.fps, css: state.css, js: state.js)
                renderer.filter = state.texture.filter.map(ImageFilter.init(configuration:))
                RenderTextureManager.shared.set(renderer, id: object.id)
                configure(sceneObject)
                group.leave()
            case .wind:
                configure(sceneObject)
                group.leave()
            }
            objects.append(sceneObject)
        }

        group.notify(queue: .main) {
            Logger.log("finish loadObjects")
            self.updateObjectOrder()
        }
    }
}

extension SceneObjectManager {
    public func addImage(url: URL) {
        let renderer = ImageRenderer(imageURL: url, filter: nil)
        let id = RenderTextureManager.shared.add(renderer)
        let canvasSize = UniBridge.shared.canvasCGSize
        add(.init(id: id, type: .image(.init(url: url, size: .init(width: renderer.size.width / canvasSize.width, height: renderer.size.height / canvasSize.height), filter: nil)), isHidden: false, isLocked: false))
    }
}
