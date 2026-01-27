import Foundation

public extension URL {
    static var applicationSupportDirectoryWithBundleID: URL {
        URL.applicationSupportDirectory.appendingPathComponent(Bundle.main.bundleIdentifier!)
    }

    static var sceneMetadata: URL {
        applicationSupportDirectoryWithBundleID.appendingPathComponent("scenes.json")
    }

    static var scenesDirectory: URL {
        applicationSupportDirectoryWithBundleID.appendingPathComponent("scenes")
    }

    static func sceneRoot(sceneId id: Int32) -> URL {
        scenesDirectory.appendingPathComponent("\(id)")
    }

    static func scene(sceneId id: Int32) -> URL {
        sceneRoot(sceneId: id).appendingPathComponent("data")
    }

    static var shortcutMetadata: URL {
        applicationSupportDirectoryWithBundleID.appendingPathComponent("shortcuts.json")
    }

    static var shortcutRootDirectory: URL {
        applicationSupportDirectoryWithBundleID.appendingPathComponent("shortcuts")
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
