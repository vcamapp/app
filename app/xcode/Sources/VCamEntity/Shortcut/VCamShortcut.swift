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

    public static func create(id: UUID = UUID(), configurations: [AnyVCamActionConfiguration] = []) -> Self {
        .init(id: id, title: "", configurations: configurations)
    }
}

public protocol VCamActionConfiguration: Identifiable<UUID>, Codable, Equatable {
    var id: UUID { get set }

    static var `default`: Self { get }

    func erased() -> AnyVCamActionConfiguration
}

public enum AnyVCamActionConfiguration: VCamActionConfiguration {
    case emoji(configuration: VCamEmojiActionConfiguration)
    case motion(configuration: VCamMotionActionConfiguration)
    case blendShape(configuration: VCamBlendShapeActionConfiguration)

    var configuration: any VCamActionConfiguration {
        switch self {
        case .emoji(let configuration as any VCamActionConfiguration),
                .motion(let configuration as any VCamActionConfiguration),
                .blendShape(let configuration as any VCamActionConfiguration):
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

