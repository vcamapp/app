//
//  VCamShortcutMetadata.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/03/30.
//


import Foundation

public struct VCamShortcutMetadata: Codable {
    public init(version: Int = 2, ids: [UUID] = []) {
        self.version = version
        self.ids = ids
    }

    /// for migration
    public var version = 2 // 1: -0.9.4, 2: 0.9.5-
    public var ids: [UUID] = []
}
