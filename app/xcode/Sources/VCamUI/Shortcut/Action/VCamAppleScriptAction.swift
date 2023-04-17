//
//  VCamAppleScriptAction.swift
//
//
//  Created by Tatsuya Tanaka on 2023/04/16.
//

import AppKit
import VCamEntity
import VCamLocalization
import struct SwiftUI.Image

public struct VCamAppleScriptAction: VCamAction {
    public init(configuration: VCamAppleScriptActionConfiguration) {
        self.configuration = configuration
    }

    public var configuration: VCamAppleScriptActionConfiguration
    public var name: String { "AppleScript" }
    public var icon: Image { Image(systemName: "applescript") }

    public static let scriptName = "script.applescript"

    @MainActor
    public func callAsFunction(context: VCamActionContext) async throws {
        do {
            try await NSAppleScript.execute(contentsOf: .shortcutResource(id: context.shortcut.id, actionId: configuration.id, name: Self.scriptName))
        } catch {
            throw VCamActionError(error.localizedDescription)
        }
    }
}
