import Foundation
import CoreGraphics
import VCamEntity
import VCamData
import VCamDefaults
import VCamBridge

/// The subtitle overlay, drawn through the text-object pipeline. It belongs to no scene:
/// the text lives in UserDefaults (`UniState.message`) so it can be set from the toolbar or
/// the external API, and the style and placement are stored globally so every scene shows it.
///
/// Unlike a scene text object, whose on-screen width is fixed by the user, a subtitle keeps
/// its glyph size steady while the text changes: it wraps at 90% of the canvas width and
/// grows upward from a fixed bottom edge, like broadcast subtitles.
@MainActor
public enum SubtitleTextObject {
    /// The text is excluded: the message key owns it. The placement is stored as the
    /// glyph scale plus anchors, because the box itself changes with every utterance.
    fileprivate struct Style: Codable {
        /// Fills in the default placement, which depends on the canvas the engine reports
        @MainActor init(configuration: TextObjectConfiguration, scale: Double? = nil, centerX: Double? = nil, bottomY: Double? = nil) {
            self.configuration = configuration
            // The text is what the object is sized against, so it can't be part of the style
            self.configuration.text = ""
            self.scale = scale ?? TextObjectPlacement.defaultScale(fontSize: configuration.fontSize)
            self.centerX = centerX ?? 0
            self.bottomY = bottomY ?? defaultBottomY
        }

        var configuration: TextObjectConfiguration
        var scale: Double // On-screen pixels per bitmap pixel
        var centerX: Double
        var bottomY: Double
    }

    private static var observer: (any NSObjectProtocol)?
    private static var pendingUpdate: Task<Void, Never>?
    private static var isStyleEditorOpen = false

    /// Recreates the subtitle; called after a scene rebuilt the engine's object list.
    /// The engine dropped its object there, so this can't diff against what it had.
    public static func reapply() {
        subscribeIfNeeded()
        recreate()
    }

    // The bitmap carries the outline and shadow padding around the glyphs, so the visible
    // text sits noticeably higher than the region's bottom edge
    private static let defaultBottomY = -0.47

    /// The subtitle as an object and its text payload, which every operation on it needs
    private static var current: (object: SceneObject, payload: SceneObject.Text)? {
        guard let object = SceneObjectManager.shared.subtitleObject, case let .text(payload) = object.type else { return nil }
        return (object, payload)
    }

    /// Opens the text editor for the subtitle's own style; works before any text was typed
    public static func showStyleEditor() {
        var configuration = current?.payload.configuration ?? loadStyle()?.configuration ?? TextObjectPreset.subtitleDefault
        // The toolbar field owns the text, so it is the one the editor starts from
        configuration.text = UniState.shared.subtitle
        let placement = TextPlacementSupport(hint: .subtitleDragHint, setEditing: setEditing, reset: resetPlacement)
        TextRenderer.showPreferences(configuration: configuration, allowsEmptyText: true, resetConfiguration: TextObjectPreset.subtitleDefault, placement: placement) { configuration in
            if let current, !configuration.text.isEmpty {
                apply(configuration, to: current.object, payload: current.payload)
                persistStyle()
            } else {
                persist(configuration: configuration)
            }
            // Setting the text also creates or removes the object
            UniState.shared.subtitle = configuration.text
        }
    }

    /// The subtitle stays locked on the canvas so that arranging other objects can't
    /// grab it; its editor frees it for as long as that window is open
    private static func setEditing(_ isEditing: Bool) {
        isStyleEditorOpen = isEditing
        guard let object = SceneObjectManager.shared.subtitleObject else { return }
        SceneObjectManager.shared.setSubtitleLocked(!isEditing, of: object)
    }

    /// Brings an off-screen or shrunken subtitle back to the bottom of the canvas
    /// at the default scale, without touching its style
    public static func resetPlacement() {
        if let style = loadStyle() {
            save(Style(configuration: style.configuration))
        }
        recreate()
    }

    /// Rebuilds the engine object from scratch with the current saved style
    private static func recreate() {
        pendingUpdate?.cancel()
        SceneObjectManager.shared.subtitleObject = nil
        // Stops the renderer from asking the engine to resize a texture it no longer has
        RenderTextureManager.shared.remove(id: SceneObject.subtitleID)
        update(text: UniState.shared.subtitle)
    }

    /// Remembers the current style and placement, so they survive scene switches and restarts
    static func persistStyle() {
        guard let current, let renderer = RenderTextureManager.shared.textRenderer(id: current.object.id) else { return }
        let region = current.payload.region
        save(Style(
            configuration: current.payload.configuration,
            scale: renderer.layout.displayScale,
            centerX: region.origin.x,
            bottomY: region.origin.y - region.height / 2
        ))
    }

    /// Stores an edited style while no subtitle is on screen, keeping the saved placement
    private static func persist(configuration: TextObjectConfiguration) {
        let existing = loadStyle()
        save(Style(configuration: configuration, scale: existing?.scale, centerX: existing?.centerX, bottomY: existing?.bottomY))
    }

    private static func save(_ style: Style) {
        UserDefaults.standard.set(style, for: .subtitleStyle)
    }

    private static func subscribeIfNeeded() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(forName: .subtitleDidChange, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                // The field reports every keystroke, and each one rasterizes the bitmap and
                // makes the engine reallocate the texture, so a burst is coalesced into one
                pendingUpdate?.cancel()
                pendingUpdate = Task {
                    try? await Task.sleep(for: .milliseconds(150))
                    guard !Task.isCancelled else { return }
                    update(text: UniState.shared.subtitle)
                }
            }
        }
    }

    private static func update(text: String) {
        let manager = SceneObjectManager.shared
        guard !text.isEmpty else {
            manager.removeSubtitle()
            return
        }

        if let current {
            guard current.payload.configuration.text != text else { return }
            var configuration = current.payload.configuration
            configuration.text = text
            apply(configuration, to: current.object, payload: current.payload)
        } else {
            let style = loadStyle() ?? Style(configuration: TextObjectPreset.subtitleDefault)
            var configuration = style.configuration
            configuration.text = text
            let scale = TextObjectPlacement.normalizedScale(style.scale, fontSize: configuration.fontSize)
            let canvasSize = UniBridge.shared.canvasCGSize
            configuration.wrapCharacters = TextObjectPlacement.wrapCharacters(forScale: scale, fontSize: configuration.fontSize)
            let renderer = TextRenderer(layout: .init(configuration: configuration, displayScale: scale))
            RenderTextureManager.shared.set(renderer, id: SceneObject.subtitleID)
            let size = renderer.size / canvasSize
            manager.addSubtitle(.init(
                id: SceneObject.subtitleID,
                type: .text(.init(configuration: configuration, region: .init(
                    origin: .init(x: style.centerX, y: style.bottomY + size.height / 2),
                    size: size
                ))),
                name: String(localized: .subtitle),
                isHidden: false,
                isLocked: !isStyleEditorOpen
            ))
        }
    }

    /// Re-renders with a new configuration while keeping the glyph scale and the bottom
    /// edge, so a longer text wraps and grows instead of shrinking to the previous width
    private static func apply(_ configuration: TextObjectConfiguration, to object: SceneObject, payload: SceneObject.Text) {
        guard let renderer = RenderTextureManager.shared.textRenderer(id: object.id) else { return }
        var configuration = configuration
        configuration.wrapCharacters = TextObjectPlacement.wrapCharacters(forScale: renderer.layout.displayScale, fontSize: configuration.fontSize)
        // Broadcast-style: always centered above a fixed bottom edge, regardless of alignment
        SceneObjectManager.shared.applyText(configuration, to: object, payload: payload, horizontal: .center, vertical: .bottom)
        SceneObjectManager.shared.addSubtitle(object)
    }

    private static func loadStyle() -> Style? {
        UserDefaults.standard.value(for: .subtitleStyle)
    }
}

extension SubtitleTextObject.Style: UserDefaultsJSONValue {}

private extension UserDefaults.Key {
    static var subtitleStyle: UserDefaults.Key<SubtitleTextObject.Style?> { .init("vc_message_style", default: nil) }
}

extension SceneObjectManager {
    /// Puts the subtitle on screen, or refits the one that is already there to its
    /// re-rendered bitmap. The subtitle lives outside the scenes, so nothing is saved here.
    func addSubtitle(_ object: SceneObject) {
        let isNew = subtitleObject == nil
        subtitleObject = object
        configure(object)
        if isNew {
            // The order only has to be re-sent when the engine gained an object
            updateObjectOrder(persist: false)
        }
    }

    func removeSubtitle() {
        guard let object = subtitleObject else { return }
        subtitleObject = nil
        RenderTextureManager.shared.remove(id: object.id)
        deleteFromEngine(id: object.id)
    }

    /// The subtitle isn't in `objects`, so the shared `setLocked(_:id:)` can't reach it
    func setSubtitleLocked(_ isLocked: Bool, of object: SceneObject) {
        var object = object
        object.isLocked = isLocked
        subtitleObject = object
        applyState(object)
    }
}
