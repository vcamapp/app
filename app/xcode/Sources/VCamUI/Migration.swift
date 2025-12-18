//
//  Migration.swift
//
//
//  Created by Tatsuya Tanaka on 2022/03/13.
//

import Foundation
import VCamData
import VCamEntity
import VCamLogger
import VCamCamera
import AppKit

public struct Migration {
    public static func migrate() async {
        let previousVersion = UserDefaults.standard.value(for: .previousVersion)

        do {
            try await migrationFirst(previousVersion: previousVersion)

#if FEATURE_3
            try migration095(previousVersion: previousVersion)
            try await migration0110(previousVersion: previousVersion)
            try await migration0131(previousVersion: previousVersion)
#endif
        } catch {
            Logger.error(error)
        }

        UserDefaults.standard.set(Bundle.main.version, for: .previousVersion)
    }
}

extension Migration {
    static func migrationFirst(previousVersion: String) async throws {
        guard previousVersion.isEmpty else { return }
        await VCamAlert.showModal(title: L10n.installVirtualCamera.text, message: L10n.explainAboutInstallingCameraExtension.text, canCancel: false)
        Task {
            do {
                if CoreMediaSinkStream.isInstalled {
                    NSWorkspace.shared.open(.cameraExtension)
                }
                try await CameraExtension().installExtension()
                _ = await VirtualCameraManager.shared.installAndStartCameraExtension()
                await VCamAlert.showModal(title: L10n.success.text, message: L10n.restartAfterInstalling.text, canCancel: false)
            } catch {
                await VCamAlert.showModal(title: L10n.failure.text, message: L10n.failedToInstallCameraExtension.text, canCancel: false)
            }
        }
    }

    static func migration095(previousVersion: String) throws {
        guard previousVersion == "0.9.4" else { return } // only for 0.9.4
        Logger.log("")

        var metadata = try VCamShortcutMetadata.load()
        guard metadata.version == 1 else { return }

        let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        for id in metadata.ids {
            let url = URL.shortcutDirectory(id: id)
            let temporaryURL = temporaryDirectoryURL.appendingPathComponent(id.uuidString)
            do {
                try FileManager.default.moveItem(at: url, to: temporaryURL)
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                try FileManager.default.moveItem(at: temporaryURL, to: .shortcutData(id: id))

                try FileManager.default.createDirectory(at: .shortcutResourceDirectory(id: id), withIntermediateDirectories: true)
            } catch {
                Logger.error(error)
            }
        }

        metadata.version = 2
        try metadata.save()
    }

    @MainActor
    static func migration0110(previousVersion: String) async throws {
        guard LegacyPluginHelper.isPluginInstalled() else {
            return
        }

        let version = previousVersion.components(separatedBy: ".").compactMap(Int.init)
        guard version.count == 3, version[0] == 0, version[1] < 12 else {
            return
        }
        Logger.log("")

        let isNewCameraInstalled = CoreMediaSinkStream.isInstalled

        await VCamAlert.showModal(
            title: isNewCameraInstalled ? L10n.deleteOldDALPlugin.text : L10n.migrateToNewVirtualCamera.text,
            message: isNewCameraInstalled ? L10n.deleteOldDALPluginMessage.text : L10n.migrateToNewVirtualCameraMessage.text,
            canCancel: false
        )

        while LegacyPluginHelper.isPluginInstalled() {
            await LegacyPluginHelper.uninstallPlugin(canCancel: false)
        }

        if !isNewCameraInstalled {
            MacWindowManager.shared.open(VCamSettingView(tab: .virtualCamera))
        }
    }

    @MainActor
    static func migration0131(previousVersion: String) async throws {        
        let version = previousVersion.components(separatedBy: ".").compactMap(Int.init)
        guard version.count == 3 else { return }
        
        // If updated from a version prior to 0.13.1
        if version[0] == 0 && (version[1] < 13 || (version[1] == 13 && version[2] < 1)) {
            Logger.log("Migrating to 0.13.1 from \(previousVersion)")

            await VCamAlert.showModal(
                title: L10n.update.text,
                message: L10n.explainAboutReinstallingCameraExtension.text,
                canCancel: false
            )

            do {
                try? await CameraExtension().uninstallExtension()
                NSWorkspace.shared.open(.cameraExtension)
                try await CameraExtension().installExtension()
                _ = await VirtualCameraManager.shared.installAndStartCameraExtension()
                await VCamAlert.showModal(title: L10n.success.text, message: L10n.restartAfterInstalling.text, canCancel: false)
            } catch {
                await VCamAlert.showModal(title: L10n.failure.text, message: L10n.failedToInstallCameraExtension.text, canCancel: false)
                Logger.error(error)
            }
        }
    }
}
