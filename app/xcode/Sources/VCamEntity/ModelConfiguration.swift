//
//  ModelConfiguration.swift
//
//
//  Created by tattn on 2025/12/06.
//

import Foundation

public struct ModelConfiguration: Sendable {
    public init() {}

    public var isMotionLoopEnabled: [Avatar.Motion: Bool] = [:]
}
