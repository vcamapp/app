//
//  VCamDelayActionConfiguration.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/02.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct VCamWaitActionConfiguration: VCamActionConfiguration {
    public var id = UUID()
    public var duration: TimeInterval = 0

    public static var `default`: Self { .init() }

    public func erased() -> AnyVCamActionConfiguration {
        .wait(configuration: self)
    }
}
