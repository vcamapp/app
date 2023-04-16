//
//  LegacyPluginHelper.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/03/13.
//

import Foundation
import AppKit
import VCamLogger


private let dalPath = URL(fileURLWithPath: "/Library/CoreMediaIO/Plug-Ins/DAL/")
private let pluginPath = dalPath.appendingPathComponent("VCam.plugin")
private let sourcePluginPath = URL(fileURLWithPath: Bundle.main.bundlePath).appendingPathComponent("Contents/VCam.plugin")

public struct LegacyPluginHelper {
    private static var pluginVersion: String {
        let plistURL = sourcePluginPath.appendingPathComponent("Contents/Info.plist")
        let plist = NSDictionary(contentsOf: plistURL)
        return plist?["CFBundleShortVersionString"] as? String ?? ""
    }

    @MainActor
    public static func checkUpdate() async {
        let pluginInstalled = FileManager.default.fileExists(atPath: pluginPath.path)
        var pluginUpdateNeeded = false

        if pluginInstalled {
            pluginUpdateNeeded = pluginVersion != UserDefaults.standard.value(for: .pluginVersion)
        }

        if !pluginInstalled || pluginUpdateNeeded {
            await installPlugin(isUpdate: pluginUpdateNeeded)
        }
    }

    private static func runAppleScript(_ source: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                let script = NSAppleScript(source: source)!
                var error: NSDictionary?
                _ = script.executeAndReturnError(&error).stringValue ?? ""

                if let error {
                    let message = error[NSAppleScript.errorMessage] as? String ?? ""
                    let code = error[NSAppleScript.errorNumber] as? Int ?? 0
                    continuation.resume(with: .failure(NSError(domain: "tattn.vcam", code: 0, userInfo: [NSLocalizedDescriptionKey: "\(message)(\(code))"])))
                    return
                }

                continuation.resume()
            }
        }
    }

    @MainActor
    public static func installPlugin(isUpdate: Bool) async {
        Logger.log(event: .installPlugin)

        guard await VCamAlert.showModal(
            title: L10n.installPlugin(isUpdate ? L10n.update.text : L10n.add.text).text,
            message: L10n.installOne(pluginPath.path).text, canCancel: true) == .ok
        else {
            Logger.log("cancel")
            return
        }

        do {
            // Get the necessary permissions for installation by AppleScript
            let rm = "rm -rf \\\"\(pluginPath.path)\\\""
            let cp = "cp -r \\\"\(sourcePluginPath.path)\\\" \\\"\(pluginPath.path)\\\""
            try await runAppleScript("do shell script \"\(rm) && \(cp)\" with administrator privileges")

            await VCamAlert.showModal(title: L10n.success.text, message: L10n.restartAfterInstalling.text, canCancel: false)
            UserDefaults.standard.set(pluginVersion, for: .pluginVersion)
        } catch {
            await VCamAlert.showModal(title: L10n.failure.text, message: error.localizedDescription, canCancel: false)
            Logger.log("error")
        }
    }

    @MainActor
    public static func uninstallPlugin() async {
        guard await VCamAlert.showModal(title: L10n.deletePlugin.text, message: L10n.deleteOne(pluginPath).text, canCancel: true) == .ok else {
            return
        }
        do {
            // Get the necessary permissions for uninstallation by AppleScript
            let rm = "rm -r \\\"\(pluginPath.path)\\\""
            try await runAppleScript("do shell script \"\(rm)\" with administrator privileges")
            
            await VCamAlert.showModal(title: L10n.success.text, message: L10n.completeUninstalling.text, canCancel: false)
        } catch {
            await VCamAlert.showModal(title: L10n.failure.text, message: error.localizedDescription, canCancel: false)
        }
    }
}