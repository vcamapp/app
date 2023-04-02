//
//  VCamShortcutMetadata.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/03/30.
//


import Foundation

public struct VCamShortcutMetadata: Codable {
    public init(version: Int = 1, ids: [UUID] = []) {
        self.version = version
        self.ids = ids
    }

    /// for migration
    public var version = 1
    public var ids: [UUID] = []
}
