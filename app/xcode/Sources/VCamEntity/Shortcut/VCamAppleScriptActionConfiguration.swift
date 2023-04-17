//
//  VCamAppleScriptActionConfiguration.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/16.
//

import Foundation

public struct VCamAppleScriptActionConfiguration: VCamActionConfiguration {
    public init(id: UUID = UUID()) {
        self.id = id
    }

    public var id = UUID()

    public static var `default`: Self { .init() }

    public func erased() -> AnyVCamActionConfiguration {
        .appleScript(configuration: self)
    }
}
