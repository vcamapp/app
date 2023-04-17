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

    func callAsFunction(context: VCamActionContext) async throws

    func deleteResources(shortcut: VCamShortcut)
}

public extension VCamAction {
    var id: UUID {
        configuration.id
    }

    func deleteResources(shortcut: VCamShortcut) {
        try? FileManager.default.removeItem(at: .shortcutResourceActionDirectory(id: shortcut.id, actionId: id))
    }
}

public struct VCamActionContext {
    public let shortcut: VCamShortcut

    public static let empty = VCamActionContext(shortcut: .create())
}
