import CoreGraphics
import Foundation
import VCamControl
import VCamEntity

/// The object, text, subtitle style, image, video and web methods of the public API
@MainActor
struct SceneObjectAPIHandler {
    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "heic", "webp", "tiff"]
    private static let videoExtensions: Set<String> = ["mp4", "mov", "m4v"]
    private static let defaultWebSize = CGSize(width: 800, height: 600)
    private static let defaultWebFPS = 6
    private static let webSizeRange = 1...7680
    private static let webFPSRange = 1...60

    let connectionID: UUID
    let staging: UploadStaging

    private func withProvider<Result>(_ body: (any SceneObjectControlling) async throws -> Result) async throws -> Result {
        guard let provider = SceneObjectControl.provider else {
            throw VCamError.notReady(data: .errorCode("not_ready"))
        }
        do {
            return try await body(provider)
        } catch let error as SceneObjectControlError {
            throw Self.apiError(error)
        }
    }

    private static func apiError(_ error: SceneObjectControlError) -> any Error {
        switch error {
        case .notFound: VCamError.objectNotFound(data: .errorCode("object_not_found"))
        case .locked: VCamError.objectLocked(data: .errorCode("object_locked"))
        case .typeMismatch: VCamError.objectTypeMismatch(data: .errorCode("object_type_mismatch"))
        case .noPlacement: VCamError.objectHasNoPlacement(data: .errorCode("object_has_no_placement"))
        case .notDuplicable: VCamError.objectNotDuplicable(data: .errorCode("object_not_duplicable"))
        case .notRemovable: VCamError.objectNotRemovable(data: .errorCode("object_not_removable"))
        case .presetNotFound: TextStyleMapping.invalidParameter("preset", "expected an id from text.listPresets")
        case .invalidImage: VCamError.invalidImage(data: .errorCode("invalid_image"))
        case .invalidVideo: VCamError.invalidVideo(data: .errorCode("invalid_video"))
        }
    }

    private static func objectID(_ value: Int) throws -> Int32 {
        guard let id = Int32(exactly: value) else {
            throw VCamError.objectNotFound(data: .errorCode("object_not_found"))
        }
        return id
    }

    // MARK: - Objects

    func list() async throws -> [ObjectInfo] {
        try await withProvider { provider in
            provider.objects.map { object in
                ObjectInfo(
                    id: Int(object.id),
                    isHidden: object.isHidden,
                    isLocked: object.isLocked,
                    name: object.name,
                    placement: object.placement.map {
                        ObjectPlacement(height: $0.height, width: $0.width, x: $0.origin.x, y: $0.origin.y)
                    },
                    type: Self.objectType(object.kind)
                )
            }
        }
    }

    private static func objectType(_ kind: SceneObjectControl.Kind) -> ObjectInfoType {
        switch kind {
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

    func update(
        objectId: Int,
        name: String?,
        isHidden: Bool?,
        isLocked: Bool?,
        placement: ObjectPlacementUpdate?,
        animation: ControlAnimation?
    ) async throws {
        let id = try Self.objectID(objectId)
        let placement = try placement.map(Self.placementChange)
        try await withProvider { provider in
            guard let animation, placement != nil || isHidden != nil else {
                try provider.update(id: id, change: .init(name: name, isHidden: isHidden, isLocked: isLocked, placement: placement))
                return
            }
            // A lock in the same request applies after the animations, which it would otherwise reject
            if name != nil {
                try provider.update(id: id, change: .init(name: name))
            }
            let move = Task { @MainActor in
                if let placement {
                    try await provider.animatePlacement(id: id, placement: placement, animation: animation)
                }
            }
            let fade = Task { @MainActor in
                if let isHidden {
                    try await provider.animateVisibility(id: id, isHidden: isHidden, animation: animation)
                }
            }
            try await move.value
            try await fade.value
            if let isLocked {
                try provider.update(id: id, change: .init(isLocked: isLocked))
            }
        }
    }

    private static func placementChange(_ placement: ObjectPlacementUpdate) throws -> SceneObjectControl.PlacementChange {
        for value in [placement.x, placement.y, placement.width].compactMap(\.self) where !value.isFinite {
            throw TextStyleMapping.invalidParameter("placement", "expected finite numbers")
        }
        if let width = placement.width, width <= 0 {
            throw TextStyleMapping.invalidParameter("width", "expected a positive number")
        }
        return .init(x: placement.x, y: placement.y, width: placement.width)
    }

    func move(objectId: Int, index: Int) async throws {
        let id = try Self.objectID(objectId)
        try await withProvider { try $0.move(id: id, toIndex: index) }
    }

    func duplicate(objectId: Int) async throws -> Int {
        let id = try Self.objectID(objectId)
        return try await withProvider { Int(try await $0.duplicate(id: id)) }
    }

    func remove(objectId: Int) async throws {
        let id = try Self.objectID(objectId)
        try await withProvider { try $0.remove(id: id) }
    }

    /// The object exists by now, so a rejected name or placement leaves it in place with what it has
    private func finishAdding(_ id: Int32, name: String?, placement: ObjectPlacementUpdate?, provider: any SceneObjectControlling) throws -> Int {
        let placement = try placement.map(Self.placementChange)
        if name != nil || placement != nil {
            try provider.update(id: id, change: .init(name: name, placement: placement))
        }
        return Int(id)
    }

    // MARK: - Text

    private func merged(
        _ configuration: TextObjectConfiguration,
        preset: String?,
        style: TextStyle?,
        provider: any SceneObjectControlling
    ) throws -> TextObjectConfiguration {
        var configuration = configuration
        if let preset {
            configuration = try provider.applyingTextPreset(id: preset, to: configuration)
        }
        if let style {
            try TextStyleMapping.apply(style, to: &configuration, fontNames: provider.fontNames)
        }
        return configuration
    }

    func addText(text: String, name: String?, preset: String?, style: TextStyle?, placement: ObjectPlacementUpdate?) async throws -> Int {
        try await withProvider { provider in
            var configuration = provider.defaultTextConfiguration
            configuration.text = text
            configuration = try merged(configuration, preset: preset, style: style, provider: provider)
            return try finishAdding(provider.addText(configuration), name: name, placement: placement, provider: provider)
        }
    }

    func getText(objectId: Int) async throws -> TextGetResult {
        let id = try Self.objectID(objectId)
        return try await withProvider { provider in
            let configuration = try provider.textConfiguration(id: id)
            return TextGetResult(style: TextStyleMapping.style(of: configuration), text: configuration.text)
        }
    }

    func updateText(objectId: Int, text: String?, preset: String?, style: TextStyle?) async throws {
        let id = try Self.objectID(objectId)
        try await withProvider { provider in
            var configuration = try provider.textConfiguration(id: id)
            if let text {
                configuration.text = text
            }
            configuration = try merged(configuration, preset: preset, style: style, provider: provider)
            try provider.updateText(id: id, configuration: configuration)
        }
    }

    func listTextPresets() async throws -> [TextPreset] {
        try await withProvider { $0.textPresets.map { TextPreset(id: $0.id, name: $0.name) } }
    }

    func listFonts() async throws -> [String] {
        try await withProvider { $0.fontNames }
    }

    // MARK: - Subtitle

    func subtitleStyle() async throws -> SubtitleGetStyleResult {
        try await withProvider { provider in
            let style = provider.subtitleStyle
            return SubtitleGetStyleResult(
                placement: SubtitlePlacement(bottomY: style.bottomY, size: style.size, x: style.x),
                style: TextStyleMapping.style(of: style.configuration)
            )
        }
    }

    func setSubtitleStyle(preset: String?, style: TextStyle?, placement: SubtitlePlacement?, animation: ControlAnimation?) async throws {
        for value in [placement?.x, placement?.bottomY, placement?.size].compactMap(\.self) where !value.isFinite {
            throw TextStyleMapping.invalidParameter("placement", "expected finite numbers")
        }
        if let size = placement?.size, size <= 0 {
            throw TextStyleMapping.invalidParameter("size", "expected a positive number")
        }
        try await withProvider { provider in
            var subtitle = provider.subtitleStyle
            subtitle.configuration = try merged(subtitle.configuration, preset: preset, style: style, provider: provider)
            subtitle.x = placement?.x ?? subtitle.x
            subtitle.bottomY = placement?.bottomY ?? subtitle.bottomY
            subtitle.size = placement?.size ?? subtitle.size
            if let animation, placement != nil {
                await provider.animateSubtitleStyle(subtitle, animation: animation)
            } else {
                provider.setSubtitleStyle(subtitle)
            }
        }
    }

    // MARK: - Images

    func beginImageImport(filename: String) throws -> UUID {
        do {
            return try staging.begin(filename: filename, allowedExtensions: Self.imageExtensions, connectionID: connectionID)
        } catch {
            throw VCamError.importFailed(data: .errorCode("import_failed"))
        }
    }

    func commitImageImport(importId: UUID, name: String?, placement: ObjectPlacementUpdate?) async throws -> Int {
        do {
            return try await withProvider { provider in
                try await staging.commit(importId: importId, connectionID: connectionID) { fileURL in
                    try finishAdding(provider.addImage(fileURL: fileURL), name: name, placement: placement, provider: provider)
                }
            }
        } catch UploadError.importNotFound {
            throw VCamError.importNotFound(data: .errorCode("import_not_found"))
        } catch UploadError.invalidUpload {
            throw VCamError.importFailed(data: .errorCode("import_failed"))
        }
    }

    func cancelImageImport(importId: UUID) throws {
        do {
            try staging.cancel(importId: importId, connectionID: connectionID)
        } catch {
            throw VCamError.importNotFound(data: .errorCode("import_not_found"))
        }
    }

    // MARK: - Videos

    func beginVideoImport(filename: String) throws -> UUID {
        do {
            return try staging.begin(filename: filename, allowedExtensions: Self.videoExtensions, connectionID: connectionID)
        } catch {
            throw VCamError.importFailed(data: .errorCode("import_failed"))
        }
    }

    func commitVideoImport(importId: UUID, name: String?, placement: ObjectPlacementUpdate?, isLooping: Bool?, isMuted: Bool?) async throws -> VideoImportCommitResult {
        do {
            return try await withProvider { provider in
                try await staging.commit(importId: importId, connectionID: connectionID) { fileURL in
                    let id = try await provider.addVideo(fileURL: fileURL, isLooping: isLooping ?? true, isMuted: isMuted ?? true)
                    let objectId = try finishAdding(id, name: name, placement: placement, provider: provider)
                    return VideoImportCommitResult(duration: try await provider.videoState(id: id).duration, objectId: objectId)
                }
            }
        } catch UploadError.importNotFound {
            throw VCamError.importNotFound(data: .errorCode("import_not_found"))
        } catch UploadError.invalidUpload {
            throw VCamError.importFailed(data: .errorCode("import_failed"))
        }
    }

    func cancelVideoImport(importId: UUID) throws {
        do {
            try staging.cancel(importId: importId, connectionID: connectionID)
        } catch {
            throw VCamError.importNotFound(data: .errorCode("import_not_found"))
        }
    }

    func video(objectId: Int) async throws -> VideoState {
        let id = try Self.objectID(objectId)
        return try await withProvider { Self.videoState(try await $0.videoState(id: id)) }
    }

    func updateVideo(objectId: Int, isPlaying: Bool?, time: Double?, isLooping: Bool?, isMuted: Bool?) async throws -> VideoState {
        let id = try Self.objectID(objectId)
        if let time, !time.isFinite || time < 0 {
            throw TextStyleMapping.invalidParameter("time", "expected a non-negative number of seconds")
        }
        return try await withProvider { provider in
            try provider.updateVideo(id: id, change: .init(isPlaying: isPlaying, time: time, isLooping: isLooping, isMuted: isMuted))
            return Self.videoState(try await provider.videoState(id: id))
        }
    }

    private static func videoState(_ state: SceneObjectControl.VideoState) -> VideoState {
        VideoState(duration: state.duration, isLooping: state.isLooping, isMuted: state.isMuted, isPlaying: state.isPlaying, time: state.time)
    }

    // MARK: - Web

    /// A file URL would let a client put any file on this Mac on the stream
    private static func webURL(_ value: String) throws -> URL {
        guard let url = URL(string: value), ["http", "https"].contains(url.scheme?.lowercased()), url.host() != nil else {
            throw TextStyleMapping.invalidParameter("url", "expected an http or https URL")
        }
        return url
    }

    private static func webSize(width: Int?, height: Int?, fallback: CGSize) throws -> CGSize {
        let width = width ?? Int(fallback.width)
        let height = height ?? Int(fallback.height)
        guard webSizeRange.contains(width), webSizeRange.contains(height) else {
            throw TextStyleMapping.invalidParameter("width", "expected width and height from 1 to 7680")
        }
        return CGSize(width: width, height: height)
    }

    private static func webFPS(_ fps: Int?) throws -> Int? {
        if let fps, !webFPSRange.contains(fps) {
            throw TextStyleMapping.invalidParameter("fps", "expected a number from 1 to 60")
        }
        return fps
    }

    func addWeb(url: String, name: String?, width: Int?, height: Int?, fps: Int?, placement: ObjectPlacementUpdate?) async throws -> Int {
        let url = try Self.webURL(url)
        let size = try Self.webSize(width: width, height: height, fallback: Self.defaultWebSize)
        let fps = try Self.webFPS(fps) ?? Self.defaultWebFPS
        return try await withProvider { provider in
            try finishAdding(provider.addWeb(url: url, size: size, fps: fps), name: name, placement: placement, provider: provider)
        }
    }

    func updateWeb(objectId: Int, url: String?, width: Int?, height: Int?, fps: Int?) async throws {
        let id = try Self.objectID(objectId)
        let url = try url.map(Self.webURL)
        let size = width == nil && height == nil ? nil : try Self.webSize(width: width, height: height, fallback: Self.defaultWebSize)
        let fps = try Self.webFPS(fps)
        try await withProvider { try $0.updateWeb(id: id, url: url, size: size, fps: fps) }
    }
}

enum AnimationMapping {
    private static let maximumDuration = 60.0

    /// nil applies the change at once
    static func animation(duration: Double?, easing: AnimationEasing?) throws -> ControlAnimation? {
        guard let duration else { return nil }
        guard duration.isFinite, (0...maximumDuration).contains(duration) else {
            throw TextStyleMapping.invalidParameter("duration", "expected a number of seconds from 0 to 60")
        }
        return duration == 0 ? nil : ControlAnimation(duration: duration, easing: controlEasing(easing ?? .easeInOut))
    }

    private static func controlEasing(_ easing: AnimationEasing) -> VCamControl.AnimationEasing {
        switch easing {
        case .linear: .linear
        case .easeIn: .easeIn
        case .easeOut: .easeOut
        case .easeInOut: .easeInOut
        }
    }
}

extension JSONValue {
    /// The `error.data` payload carrying the stable string identifier
    static func errorCode(_ code: String) -> JSONValue {
        .object(["code": .string(code)])
    }
}
