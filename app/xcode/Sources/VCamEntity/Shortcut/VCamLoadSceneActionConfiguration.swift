//
//  VCamLoadSceneActionConfiguration.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/03.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct VCamLoadSceneActionConfiguration: VCamActionConfiguration {
    public var id = UUID()
    public var sceneId: Int32 = 0

    public static var `default`: Self { .init() }

    public func erased() -> AnyVCamActionConfiguration {
        .loadScene(configuration: self)
    }
}
