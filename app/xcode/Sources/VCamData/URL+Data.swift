import Foundation

public extension URL {
    static var applicationSupportDirectoryWithBundleID: URL {
        URL.applicationSupportDirectory.appending(path: Bundle.main.bundleIdentifier!)
    }

    static var sceneMetadata: URL {
        applicationSupportDirectoryWithBundleID.appending(path: "scenes.json")
    }

    static var scenesDirectory: URL {
        applicationSupportDirectoryWithBundleID.appending(path: "scenes")
    }

    static func sceneRoot(sceneId id: Int32) -> URL {
        scenesDirectory.appending(path: "\(id)")
    }

    static func scene(sceneId id: Int32) -> URL {
        sceneRoot(sceneId: id).appending(path: "data")
    }

    static var shortcutMetadata: URL {
        applicationSupportDirectoryWithBundleID.appending(path: "shortcuts.json")
    }

    static var shortcutRootDirectory: URL {
        applicationSupportDirectoryWithBundleID.appending(path: "shortcuts")
    }

    static func shortcutDirectory(id: UUID) -> URL {
        shortcutRootDirectory.appending(path: id.uuidString)
    }

    static func shortcutData(id: UUID) -> URL {
        shortcutDirectory(id: id).appending(path: "data")
    }

    static func shortcutResourceDirectory(id: UUID) -> URL {
        shortcutDirectory(id: id).appending(path: "resources")
    }

    static func shortcutResourceActionDirectory(id: UUID, actionId: UUID) -> URL {
        shortcutDirectory(id: id).appending(path: "resources").appending(path: actionId.uuidString)
    }

    static func shortcutResource(id: UUID, actionId: UUID, name: String) -> URL {
        shortcutResourceActionDirectory(id: id, actionId: actionId).appending(path: name)
    }
}
