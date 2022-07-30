//
//  VCamSceneMetadata.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/05/08.
//

import Foundation

public struct VCamSceneMetadata: Codable {
    public init(version: Int = 1, sceneIds: [Int32] = []) {
        self.version = version
        self.sceneIds = sceneIds
    }

    /// for migration
    public var version = 1
    public var sceneIds: [Int32] = []
}
