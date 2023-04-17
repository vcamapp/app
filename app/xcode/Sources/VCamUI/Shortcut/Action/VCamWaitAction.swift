//
//  VCamWaitAction.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/02.
//

import Foundation
import VCamEntity
import VCamLocalization
import struct SwiftUI.Image

public struct VCamWaitAction: VCamAction {
    public init(configuration: VCamWaitActionConfiguration) {
        self.configuration = configuration
    }

    public var configuration: VCamWaitActionConfiguration
    public var name: String { L10n.wait.text }
    public var icon: Image { Image(systemName: "timer") }

    @MainActor
    public func callAsFunction(context: VCamActionContext) async throws {
        try await Task.sleep(nanoseconds: UInt64(TimeInterval(NSEC_PER_SEC) * configuration.duration))
    }
}
