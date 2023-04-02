//
//  VCamMotionActionConfiguration.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/02.
//

import Foundation

public struct VCamMotionActionConfiguration: VCamActionConfiguration {
    public var id = UUID()
    public var motion: VCamAvatarMotion = .hi

    public static var `default`: Self { .init() }

    public func erased() -> AnyVCamActionConfiguration {
        .motion(configuration: self)
    }
}
