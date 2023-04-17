//
//  URL+Data.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/05/08.
//

import Foundation

public extension URL {
    static var applicationSupportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent(Bundle.main.bundleIdentifier!)
    }

    static var sceneMetadata: URL {
        applicationSupportDirectory.appendingPathComponent("scenes.json")
    }

    static var scenesDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("scenes")
    }

    static func sceneRoot(sceneId id: Int32) -> URL {
        scenesDirectory.appendingPathComponent("\(id)")
    }

    static func scene(sceneId id: Int32) -> URL {
        sceneRoot(sceneId: id).appendingPathComponent("data")
    }

    static var shortcutMetadata: URL {
        applicationSupportDirectory.appendingPathComponent("shortcuts.json")
    }

    static var shortcutRootDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("shortcuts")
    }

    static func shortcutDirectory(id: UUID) -> URL {
        shortcutRootDirectory.appendingPathComponent(id.uuidString)
    }

    static func shortcutData(id: UUID) -> URL {
        shortcutDirectory(id: id).appendingPathComponent("data")
    }

    static func shortcutResourceDirectory(id: UUID) -> URL {
        shortcutDirectory(id: id).appendingPathComponent("resources")
    }

    static func shortcutResourceActionDirectory(id: UUID, actionId: UUID) -> URL {
        shortcutDirectory(id: id).appendingPathComponent("resources").appendingPathComponent(actionId.uuidString)
    }

    static func shortcutResource(id: UUID, actionId: UUID, name: String) -> URL {
        shortcutResourceActionDirectory(id: id, actionId: actionId).appendingPathComponent(name)
    }
}
