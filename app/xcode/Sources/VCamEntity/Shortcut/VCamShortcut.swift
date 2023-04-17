//
//  VCamShortcut.swift
//
//
//  Created by Tatsuya Tanaka on 2023/03/24.
//

import Foundation

public struct VCamShortcut: Codable, Identifiable, Equatable {
    public var id: UUID
    public var title: String
    public var iconName: String?
    public var configurations: [AnyVCamActionConfiguration]
    public var shortcutKey: ShortcutKey?

    public static func create(id: UUID = UUID(), configurations: [AnyVCamActionConfiguration] = []) -> Self {
        .init(id: id, title: "", configurations: configurations)
    }
}

public extension VCamShortcut {
    struct ShortcutKey: Codable, Equatable {
        public init(character: String, modifiers: UInt) {
            self.character = character
            self.modifiers = modifiers
        }

        public let character: String
        public let modifiers: UInt
    }
}

public protocol VCamActionConfiguration: Identifiable<UUID>, Codable, Equatable {
    var id: UUID { get set }

    static var `default`: Self { get }

    func erased() -> AnyVCamActionConfiguration
}

public enum AnyVCamActionConfiguration: VCamActionConfiguration {
    case emoji(configuration: VCamEmojiActionConfiguration)
    case message(configuration: VCamMessageActionConfiguration)
    case motion(configuration: VCamMotionActionConfiguration)
    case blendShape(configuration: VCamBlendShapeActionConfiguration)
    case wait(configuration: VCamWaitActionConfiguration)
    case resetCamera(configuration: VCamResetCameraActionConfiguration)
    case loadScene(configuration: VCamLoadSceneActionConfiguration)
    case appleScript(configuration: VCamAppleScriptActionConfiguration)

    var configuration: any VCamActionConfiguration {
        switch self {
        case .emoji(let configuration as any VCamActionConfiguration),
                .message(let configuration as any VCamActionConfiguration),
                .motion(let configuration as any VCamActionConfiguration),
                .blendShape(let configuration as any VCamActionConfiguration),
                .wait(let configuration as any VCamActionConfiguration),
                .resetCamera(let configuration as any VCamActionConfiguration),
                .loadScene(let configuration as any VCamActionConfiguration),
                .appleScript(let configuration as any VCamActionConfiguration):
            return configuration
        }
    }

    public var id: UUID {
        get {
            configuration.id
        }
        mutating set {
            var configuration = configuration
            configuration.id = newValue
            self = configuration.erased()
        }
    }

    public static var `default`: Self {
        fatalError()
    }

    public func erased() -> Self {
        self
    }
}
