//
//  VCamAction.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/02.
//

import Foundation
import VCamEntity
import struct SwiftUI.Image

public protocol VCamAction<Configuration>: Identifiable<UUID> {
    associatedtype Configuration: VCamActionConfiguration

    var configuration: Configuration { get set }
    var id: UUID { get }
    var name: String { get }
    var icon: Image { get }

    init(configuration: Configuration)

    func callAsFunction() async throws
}

public extension VCamAction {
    var id: UUID {
        configuration.id
    }
}
