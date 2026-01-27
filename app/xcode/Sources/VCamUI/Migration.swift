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
        } catch {
            Logger.error(error)
        }

        let version = previousVersion.components(separatedBy: ".").compactMap(Int.init)
        guard version.count == 3 else { return }

        do {
#if FEATURE_3
            try migration095(version: version)
            try await migration0110(version: version)
            try await migration0131(version: version)
#endif
            try await migration0141(version: version)
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

    static func migration095(version: [Int]) throws {
        guard version == [0, 9, 4] else { return } // only for 0.9.4
        Logger.log("")

        var metadata = try VCamShortcutMetadata.load()
        guard metadata.version == 1 else { return }

        let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        for id in metadata.ids {
            let url = URL.shortcutDirectory(id: id)
            let temporaryURL = temporaryDirectoryURL.appending(path: id.uuidString)
            do {
                try FileManager.default.moveItem(at: url, to: temporaryURL)
                try FileManager.default.createDirectoryIfNeeded(at: url)
                try FileManager.default.moveItem(at: temporaryURL, to: .shortcutData(id: id))

                try FileManager.default.createDirectoryIfNeeded(at: .shortcutResourceDirectory(id: id))
            } catch {
                Logger.error(error)
            }
        }

        metadata.version = 2
        try metadata.save()
    }

    @MainActor
    static func migration0110(version: [Int]) async throws {
        guard LegacyPluginHelper.isPluginInstalled() else {
            return
        }

        guard version[0] == 0, version[1] < 12 else {
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
    static func migration0131(version: [Int]) async throws {
        // If updated from a version prior to 0.13.1
        guard version[0] == 0 && (version[1] < 13 || (version[1] == 13 && version[2] < 1)) else { return }
        Logger.log("Migrating to 0.13.1 from \(version.map(String.init).joined(separator: "."))")

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

    static func migration0141(version: [Int]) async throws {
#if FEATURE_3
        // If updated from a version prior to 0.14.1
        guard version[0] == 0 && (version[1] < 14 || (version[1] == 14 && version[2] < 1)) else { return }
        let oldPath = URL.applicationSupportDirectory.appending(path: "tattn/VCam/prev/model.vrm")
#else
        // If updated from a version prior to 0.0.3
        guard version[0] == 0 && version[1] == 0 && version[2] < 3 else { return }
        let oldPath = URL.applicationSupportDirectory.appending(path: "Unlypt/VCam2D/prev/model")
#endif
        Logger.log("Migrating models from \(version.map(String.init).joined(separator: "."))")

        guard FileManager.default.fileExists(atPath: oldPath.path) else { return }

        do {
            let model = try await ModelManager.shared.saveModel(from: oldPath)
            Logger.log("Migrated model to: \(model.name)")
        } catch {
            Logger.error(error)
        }
    }
}
