import CoreGraphics
import Foundation
import VCamEntity

public enum SceneObjectControlError: Error {
    case notFound
    case locked
    case typeMismatch
    case noPlacement
    case notDuplicable
    case notRemovable
    case presetNotFound
    case invalidImage
    case invalidVideo
}

/// Operations on the objects of the current scene behind an injected provider:
/// the objects live in the UI layer, which registers its implementation at startup.
@MainActor
public enum SceneObjectControl {
    public enum Kind: String, Sendable {
        case avatar, image, video, screen, videoCapture, web, text, wind
    }

    public struct Object: Equatable, Sendable {
        public let id: Int32
        public let kind: Kind
        public let name: String
        public let isHidden: Bool
        public let isLocked: Bool
        /// Fractions of the canvas: the origin is the offset of the center from the center of the
        /// canvas (y grows upward). nil for objects without a rectangle on the canvas
        public let placement: CGRect?

        public init(id: Int32, kind: Kind, name: String, isHidden: Bool, isLocked: Bool, placement: CGRect?) {
            self.id = id
            self.kind = kind
            self.name = name
            self.isHidden = isHidden
            self.isLocked = isLocked
            self.placement = placement
        }
    }

    public struct VideoState: Equatable, Sendable {
        public let duration: Double
        public let time: Double
        public let isPlaying: Bool
        public let isLooping: Bool
        public let isMuted: Bool

        public init(duration: Double, time: Double, isPlaying: Bool, isLooping: Bool, isMuted: Bool) {
            self.duration = duration
            self.time = time
            self.isPlaying = isPlaying
            self.isLooping = isLooping
            self.isMuted = isMuted
        }
    }

    /// nil values stay as they are
    public struct VideoChange: Equatable, Sendable {
        public var isPlaying: Bool?
        public var time: Double?
        public var isLooping: Bool?
        public var isMuted: Bool?

        public init(isPlaying: Bool? = nil, time: Double? = nil, isLooping: Bool? = nil, isMuted: Bool? = nil) {
            self.isPlaying = isPlaying
            self.time = time
            self.isLooping = isLooping
            self.isMuted = isMuted
        }
    }

    /// nil values stay as they are
    public struct Change: Sendable {
        public var name: String?
        public var isHidden: Bool?
        public var isLocked: Bool?
        public var placement: PlacementChange?

        public init(name: String? = nil, isHidden: Bool? = nil, isLocked: Bool? = nil, placement: PlacementChange? = nil) {
            self.name = name
            self.isHidden = isHidden
            self.isLocked = isLocked
            self.placement = placement
        }

        /// A locked object keeps its name and placement. It can still be shown, hidden, and unlocked, as in the object list
        public var isAllowedWhileLocked: Bool {
            name == nil && placement == nil
        }
    }

    /// nil values stay as they are. The height follows the width, keeping the aspect ratio
    public struct PlacementChange: Sendable {
        public var x: Double?
        public var y: Double?
        public var width: Double?

        public init(x: Double? = nil, y: Double? = nil, width: Double? = nil) {
            self.x = x
            self.y = y
            self.width = width
        }
    }

    public struct TextPreset: Sendable {
        public let id: String
        public let name: String

        public init(id: String, name: String) {
            self.id = id
            self.name = name
        }
    }

    public struct SubtitleStyle: Sendable {
        public var configuration: TextObjectConfiguration
        public var x: Double
        public var bottomY: Double
        /// A multiplier of the default size
        public var size: Double

        public init(configuration: TextObjectConfiguration, x: Double, bottomY: Double, size: Double) {
            self.configuration = configuration
            self.x = x
            self.bottomY = bottomY
            self.size = size
        }
    }

    /// nil until the UI layer has registered its implementation
    public static var provider: (any SceneObjectControlling)?
}

@MainActor
public protocol SceneObjectControlling {
    var objects: [SceneObjectControl.Object] { get }
    func update(id: Int32, change: SceneObjectControl.Change) throws
    /// Finishes when the object has arrived, or when another placement change takes over
    func animatePlacement(id: Int32, placement: SceneObjectControl.PlacementChange, animation: ControlAnimation) async throws
    /// Finishes when the fade has ended, or when another visibility change takes over
    func animateVisibility(id: Int32, isHidden: Bool, animation: ControlAnimation) async throws
    func move(id: Int32, toIndex index: Int) throws
    func duplicate(id: Int32) async throws -> Int32
    func remove(id: Int32) throws

    /// The style a new text object starts from
    var defaultTextConfiguration: TextObjectConfiguration { get }
    var textPresets: [SceneObjectControl.TextPreset] { get }
    var fontNames: [String] { get }
    func applyingTextPreset(id: String, to configuration: TextObjectConfiguration) throws -> TextObjectConfiguration
    func addText(_ configuration: TextObjectConfiguration) -> Int32
    func textConfiguration(id: Int32) throws -> TextObjectConfiguration
    func updateText(id: Int32, configuration: TextObjectConfiguration) throws

    var subtitleStyle: SceneObjectControl.SubtitleStyle { get }
    func setSubtitleStyle(_ style: SceneObjectControl.SubtitleStyle)
    /// A style changes at once. Finishes when the placement has arrived, or when another style change takes over
    func animateSubtitleStyle(_ style: SceneObjectControl.SubtitleStyle, animation: ControlAnimation) async

    /// Takes a copy of the file, so the caller can remove it afterward
    func addImage(fileURL: URL) throws -> Int32
    func addWeb(url: URL, size: CGSize, fps: Int) -> Int32
    /// Rebuilds the page, so nil values reload it as it was
    func updateWeb(id: Int32, url: URL?, size: CGSize?, fps: Int?) throws

    /// Takes a copy of the file, so the caller can remove it afterward
    func addVideo(fileURL: URL, isLooping: Bool, isMuted: Bool) async throws -> Int32
    func videoState(id: Int32) async throws -> SceneObjectControl.VideoState
    func updateVideo(id: Int32, change: SceneObjectControl.VideoChange) throws
}
