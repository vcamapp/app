import AppKit
import CoreImage
import VCamControl
import VCamData
import VCamEntity

@MainActor
struct SceneObjectControlProvider: SceneObjectControlling {
    @MainActor
    private final class AnimationSlots {
        var slots: [Int32: AnimationSlot] = [:]

        func slot(id: Int32) -> AnimationSlot {
            if let slot = slots[id] { return slot }
            let slot = AnimationSlot()
            slots[id] = slot
            return slot
        }
    }

    private let placementAnimations = AnimationSlots()
    private let visibilityAnimations = AnimationSlots()
    private var manager: SceneObjectManager { .shared }

    var objects: [SceneObjectControl.Object] {
        manager.objects.map { object in
            .init(
                id: object.id,
                kind: Self.kind(of: object),
                name: object.name,
                isHidden: object.isHidden,
                isLocked: object.isLocked,
                placement: object.type.normalizedPlacement
            )
        }
    }

    private static func kind(of object: SceneObject) -> SceneObjectControl.Kind {
        switch object.type {
        case .avatar: .avatar
        case .image: .image
        case .video: .video
        case .screen: .screen
        case .videoCapture: .videoCapture
        case .web: .web
        case .text: .text
        case .wind: .wind
        }
    }

    private func object(id: Int32) throws -> SceneObject {
        try manager.objects.find(byId: id).orThrow(SceneObjectControlError.notFound)
    }

    private func unlockedObject(id: Int32) throws -> SceneObject {
        let object = try object(id: id)
        guard !object.isLocked else { throw SceneObjectControlError.locked }
        return object
    }

    func update(id: Int32, change: SceneObjectControl.Change) throws {
        var object = try object(id: id)
        guard !object.isLocked || change.changesOnlyLock else { throw SceneObjectControlError.locked }

        if let placement = change.placement {
            placementAnimations.slots[id]?.cancel()
            object.type.normalizedPlacement = try target(of: placement, for: object)
        }
        if let name = change.name {
            object.name = name
        }
        if let isLocked = change.isLocked {
            object.isLocked = isLocked
        }

        if change.placement != nil {
            commitPlacement(of: object)
        } else {
            manager.didChange(object)
        }
        if let isHidden = change.isHidden {
            visibilityAnimations.slots[id]?.cancel()
            manager.setFadingOpacity(nil, id: id)
            manager.setHidden(isHidden, id: id)
        }
    }

    /// The object stays visible until it has faded out, since the frames skip a hidden one
    func animateVisibility(id: Int32, isHidden: Bool, animation: ControlAnimation) async throws {
        let object = try unlockedObject(id: id)
        if case .wind = object.type {
            manager.setHidden(isHidden, id: id)
            return
        }
        let start = manager.isFading(id: id) ? manager.opacity(ofId: id) : (object.isHidden ? 0 : 1)
        let target: Float = isHidden ? 0 : 1
        manager.setFadingOpacity(start, id: id)
        if !isHidden {
            manager.setHidden(false, id: id)
        }

        let finished = await visibilityAnimations.slot(id: id).run(animation) { progress in
            manager.setFadingOpacity(start + (target - start) * Float(progress), id: id)
        }
        guard finished else { return }
        visibilityAnimations.slots[id] = nil
        if isHidden {
            manager.setHidden(true, id: id)
        }
        manager.setFadingOpacity(nil, id: id)
    }

    /// Follows a drag in the app: the frames read the placement directly, and saving and
    /// re-rasterizing the text wait for the end.
    func animatePlacement(id: Int32, placement: SceneObjectControl.PlacementChange, animation: ControlAnimation) async throws {
        let object = try unlockedObject(id: id)
        let target = try target(of: placement, for: object)
        guard let start = object.type.normalizedPlacement else { throw SceneObjectControlError.noPlacement }

        let finished = await placementAnimations.slot(id: id).run(animation) { progress in
            // The object may be gone by now, along with the scene it was in
            guard manager.objects.find(byId: id) != nil else { return }
            object.type.normalizedPlacement = start.interpolated(to: target, progress: progress)
        }
        guard finished else { return }
        placementAnimations.slots[id] = nil
        if let current = manager.objects.find(byId: id) {
            commitPlacement(of: current)
        }
    }

    private func target(of placement: SceneObjectControl.PlacementChange, for object: SceneObject) throws -> CGRect {
        guard let current = object.type.normalizedPlacement else { throw SceneObjectControlError.noPlacement }
        let width = placement.width ?? current.width
        return CGRect(
            x: placement.x ?? current.origin.x,
            y: placement.y ?? current.origin.y,
            width: width,
            height: current.height * width / current.width
        )
    }

    private func commitPlacement(of object: SceneObject) {
        if case .text = object.type {
            // Text re-rasterizes at its new size so that the glyphs stay crisp
            manager.update(object)
        } else {
            manager.didChange(object)
        }
    }

    func move(id: Int32, toIndex index: Int) throws {
        _ = try unlockedObject(id: id)
        guard let source = manager.objects.index(ofId: id) else { throw SceneObjectControlError.notFound }
        let target = min(max(index, 0), manager.objects.count - 1)
        manager.move(fromOffsets: IndexSet(integer: source), toOffset: target > source ? target + 1 : target)
    }

    func duplicate(id: Int32) async throws -> Int32 {
        let object = try object(id: id)
        guard let duplicatedId = await manager.duplicate(object) else { throw SceneObjectControlError.notDuplicable }
        return duplicatedId
    }

    func remove(id: Int32) throws {
        _ = try unlockedObject(id: id)
        guard manager.canRemove(byId: id) else { throw SceneObjectControlError.notRemovable }
        manager.remove(byId: id)
    }

    var defaultTextConfiguration: TextObjectConfiguration {
        TextObjectPreset.textDefault
    }

    var textPresets: [SceneObjectControl.TextPreset] {
        TextObjectPreset.all.map { .init(id: $0.id, name: String(localized: $0.name)) }
    }

    var fontNames: [String] {
        NSFontManager.shared.availableFonts
    }

    func applyingTextPreset(id: String, to configuration: TextObjectConfiguration) throws -> TextObjectConfiguration {
        let preset = try TextObjectPreset.all.first { $0.id == id }.orThrow(SceneObjectControlError.presetNotFound)
        return configuration.applyingStyle(of: preset.configuration)
    }

    func addText(_ configuration: TextObjectConfiguration) -> Int32 {
        manager.addText(configuration)
    }

    func textConfiguration(id: Int32) throws -> TextObjectConfiguration {
        try text(of: object(id: id)).configuration
    }

    func updateText(id: Int32, configuration: TextObjectConfiguration) throws {
        let object = try unlockedObject(id: id)
        let text = try text(of: object)
        manager.applyText(configuration, to: object, payload: text, horizontal: configuration.horizontalAnchor, vertical: configuration.verticalAnchor)
        manager.update(object)
    }

    private func text(of object: SceneObject) throws -> SceneObject.Text {
        guard case let .text(text) = object.type else { throw SceneObjectControlError.typeMismatch }
        return text
    }

    var subtitleStyle: SceneObjectControl.SubtitleStyle {
        SubtitleTextObject.style
    }

    func setSubtitleStyle(_ style: SceneObjectControl.SubtitleStyle) {
        SubtitleTextObject.setStyle(style)
    }

    func animateSubtitleStyle(_ style: SceneObjectControl.SubtitleStyle, animation: ControlAnimation) async {
        await SubtitleTextObject.animateStyle(style, animation: animation)
    }

    func addImage(fileURL: URL) throws -> Int32 {
        guard CIImage(contentsOf: fileURL) != nil else { throw SceneObjectControlError.invalidImage }
        // The renderer reads the file lazily, so it can't keep pointing at a file the caller removes
        let url = try VCamSceneDataStore(sceneId: SceneManager.shared.currentSceneId).copyData(fromURL: fileURL)
        return manager.addImage(url: url)
    }

    func addWeb(url: URL, size: CGSize, fps: Int) -> Int32 {
        let renderer = WebRenderer(resource: .url(url), size: size, fps: fps, css: nil, js: nil)
        let id = RenderTextureManager.shared.add(renderer)
        manager.add(.init(
            id: id,
            type: .web(.init(url: url, path: nil, fps: fps, css: nil, js: nil, textureSize: size, crop: renderer.cropRect, filter: nil)),
            isHidden: false,
            isLocked: false
        ))
        return id
    }

    func updateWeb(id: Int32, url: URL?, size: CGSize?, fps: Int?) throws {
        let object = try unlockedObject(id: id)
        guard case let .web(web) = object.type else { throw SceneObjectControlError.typeMismatch }
        if let url {
            web.url = url
            web.path = nil
        }
        if let fps {
            web.fps = fps
        }
        let renderer = WebRenderer(resource: .init(web: web), size: size ?? web.textureSize, fps: web.fps, css: web.css, js: web.js)
        manager.replaceRenderer(renderer, of: object)
    }

    func addVideo(fileURL: URL, isLooping: Bool, isMuted: Bool) async throws -> Int32 {
        do {
            return try await manager.addVideo(url: fileURL, isLooping: isLooping, isMuted: isMuted)
        } catch is VideoFileRenderer.LoadError {
            throw SceneObjectControlError.invalidVideo
        }
    }

    func videoState(id: Int32) async throws -> SceneObjectControl.VideoState {
        let (video, renderer) = try video(id: id)
        return .init(
            duration: await renderer.duration(),
            time: renderer.time,
            isPlaying: renderer.isPlaying,
            isLooping: video.isLooping,
            isMuted: video.isMuted
        )
    }

    func updateVideo(id: Int32, change: SceneObjectControl.VideoChange) throws {
        let object = try unlockedObject(id: id)
        let (_, renderer) = try video(id: id)
        manager.setVideoOptions(of: object, isLooping: change.isLooping, isMuted: change.isMuted)
        if let time = change.time {
            renderer.seek(to: time)
        }
        if let isPlaying = change.isPlaying {
            renderer.setPlaying(isPlaying)
        }
    }

    private func video(id: Int32) throws -> (SceneObject.Video, VideoFileRenderer) {
        guard case let .video(video) = try object(id: id).type,
              let renderer = RenderTextureManager.shared.drawer(id: id) as? VideoFileRenderer
        else { throw SceneObjectControlError.typeMismatch }
        return (video, renderer)
    }
}

private extension CGRect {
    func interpolated(to target: CGRect, progress: Double) -> CGRect {
        func value(_ start: CGFloat, _ end: CGFloat) -> CGFloat { start + (end - start) * progress }
        return CGRect(
            x: value(origin.x, target.origin.x),
            y: value(origin.y, target.origin.y),
            width: value(width, target.width),
            height: value(height, target.height)
        )
    }
}
