//
//  VCamDelayActionConfiguration.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/02.
//

import Foundation

public struct VCamWaitActionConfiguration: VCamActionConfiguration {
    public var id = UUID()
    public var duration: TimeInterval = 0

    public static var `default`: Self { .init() }

    public func erased() -> AnyVCamActionConfiguration {
        .wait(configuration: self)
    }
}
