//
//  VCamBlendShapeActionConfiguration.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/02.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct VCamBlendShapeActionConfiguration: VCamActionConfiguration {
    public var id = UUID()
    public var blendShape: String = ""

    public static var `default`: Self { .init() }

    public func erased() -> AnyVCamActionConfiguration {
        .blendShape(configuration: self)
    }
}
