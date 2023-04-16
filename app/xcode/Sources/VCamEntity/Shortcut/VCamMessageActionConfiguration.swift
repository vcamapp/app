//
//  VCamMessageActionConfiguration.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/16.
//

import Foundation

public struct VCamMessageActionConfiguration: VCamActionConfiguration {
    public init(id: UUID = UUID(), message: String = "") {
        self.id = id
        self.message = message
    }

    public var id = UUID()
    public var message: String = ""

    public static var `default`: Self { .init() }

    public func erased() -> AnyVCamActionConfiguration {
        .message(configuration: self)
    }
}
