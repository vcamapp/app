//
//  VCamResetCameraActionConfiguration.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/03.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct VCamResetCameraActionConfiguration: VCamActionConfiguration {
    public var id = UUID()

    public static var `default`: Self { .init() }

    public func erased() -> AnyVCamActionConfiguration {
        .resetCamera(configuration: self)
    }
}
