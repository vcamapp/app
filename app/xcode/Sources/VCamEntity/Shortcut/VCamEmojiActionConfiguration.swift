//
//  VCamEmojiActionConfiguration.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/02.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct VCamEmojiActionConfiguration: VCamActionConfiguration {
    public init(id: UUID = UUID(), emoji: String = "🎉") {
        self.id = id
        self.emoji = emoji
    }

    public var id = UUID()
    public var emoji: String = "🎉"

    public static var `default`: Self { .init() }

    public func erased() -> AnyVCamActionConfiguration {
        .emoji(configuration: self)
    }
}
