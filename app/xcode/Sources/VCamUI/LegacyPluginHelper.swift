import Foundation
import AppKit


private let dalPath = URL(fileURLWithPath: "/Library/CoreMediaIO/Plug-Ins/DAL/")
private let pluginPath = dalPath.appending(path: "VCam.plugin")

public struct LegacyPluginHelper {
    public static func isPluginInstalled() -> Bool {
        FileManager.default.fileExists(atPath: pluginPath.path)
    }

    @MainActor
    public static func uninstallPlugin(canCancel: Bool = true) async {
        guard await VCamAlert.showModal(title: String(localized: .deletePlugin), message: String(localized: .deleteOne(pluginPath.path)), canCancel: canCancel) == .ok else {
            return
        }
        do {
            // Get the necessary permissions for uninstallation by AppleScript
            let rm = "rm -r \\\"\(pluginPath.path)\\\""
            try await NSAppleScript.execute("do shell script \"\(rm)\" with administrator privileges")
            
            await VCamAlert.showModal(title: String(localized: .success), message: String(localized: .completeUninstalling), canCancel: false)
        } catch {
            await VCamAlert.showModal(title: String(localized: .failure), message: error.localizedDescription, canCancel: false)
        }
    }
}
