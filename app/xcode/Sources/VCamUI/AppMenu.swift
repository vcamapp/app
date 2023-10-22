//
//  AppMenu.swift
//
//
//  Created by Tatsuya Tanaka on 2022/02/07.
//

import Foundation
import AppKit
import VCamUIFoundation
import VCamBridge
import VCamData
import VCamCamera
import VCamTracking
import VCamLogger
import SystemExtensions

public final class AppMenu: NSObject {
    public static let shared = AppMenu()

    public let menu: NSMenu

    private override init() {
        let mainMenu: NSMenu
        if VCamSystem.shared.windowManager.isUnity {
            menu = Self.makeSubMenu(menu: NSApp.mainMenu!, title: "VCamMenu", items: [])
            mainMenu = NSApp.mainMenu!.items[0].submenu!
        } else {
            menu = NSMenu()
            mainMenu = Self.makeSubMenu(menu: menu, title: "VCam", items: [])
            NSApp.mainMenu = menu
        }

        super.init()

        setupMainMenu(subMenu: mainMenu)
        setupFileMenu(subMenu: menu)
        setupEditMenu(subMenu: menu)
        setupObjectMenu(subMenu: menu)
        setupAvatarMenu(subMenu: menu)
        setupWindowMenu(subMenu: menu)
        setupHelpMenu(subMenu: menu)
    }

    public func configure() {}

    private func makeMenuItem(title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    @discardableResult
    public static func makeSubMenu(menu: NSMenu, title: String, items: [NSMenuItem]) -> NSMenu {
        let rootItem = NSMenuItem()
        rootItem.title = title
        menu.addItem(rootItem)
        let subMenu = NSMenu(title: title)
        rootItem.submenu = subMenu
        subMenu.items = items
        return subMenu
    }

    private func setupEditMenu(subMenu: NSMenu) {
        Self.makeSubMenu(menu: subMenu, title: L10n.edit.text, items: [
            NSMenuItem(title: L10n.cut.text, action: #selector(NSText.copy(_:)), keyEquivalent: "x"),
            NSMenuItem(title: L10n.copy.text, action: #selector(NSText.copy(_:)), keyEquivalent: "c"),
            NSMenuItem(title: L10n.paste.text, action: #selector(NSText.paste(_:)), keyEquivalent: "v"),
            NSMenuItem(title: L10n.selectAll.text, action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"),
        ])
    }
}

// MARK: - Main
private extension AppMenu {
    private func setupMainMenu(subMenu: NSMenu) {
        let quitItem = makeMenuItem(title: L10n.quitVCam.text, action: #selector(quit), keyEquivalent: "q")
        subMenu.items.insert(quitItem, at: 0)
        subMenu.items.insert(.separator(), at: 0)
        let updateItem = makeMenuItem(title: L10n.checkForUpdates.text, action: #selector(checkUpdates))
        subMenu.items.insert(updateItem, at: 0)
        subMenu.items.insert(.separator(), at: 0)
        let preferenceItem = makeMenuItem(title: L10n.settings.text, action: #selector(openPreferences), keyEquivalent: ",")
        subMenu.items.insert(preferenceItem, at: 0)
        let aboutItem = makeMenuItem(title: L10n.aboutApp.text, action: #selector(about))
        subMenu.items.insert(aboutItem, at: 0)
    }

    @objc private func quit() {
        Logger.log("")
        UniBridge.shared.quitApp()
    }

    @objc private func about() {
        MacWindowManager.shared.openCredits()
    }

    @objc private func openPreferences() {
        MacWindowManager.shared.open(VCamSettingView())
    }

    @objc private func checkUpdates() {
        Task {
            await AppUpdater.vcam.presentUpdateAlert()
        }
    }
}

// MARK: - File
private extension AppMenu {
    private func setupFileMenu(subMenu: NSMenu) {
        Self.makeSubMenu(menu: subMenu, title: L10n.file.text, items: [
            makeMenuItem(title: L10n.loadVRMFile.text, action: #selector(loadVRM)),
            makeMenuItem(title: L10n.loadOnVRoidHub.text, action: #selector(openVRoidHub)),
        ])
    }

    @objc private func loadVRM() {
        Logger.log(event: .loadVRMFile)
        Logger.log("")
        guard let url = FileUtility.openFile(type: .vrm) else { return }
        UniBridge.shared.loadVRM(url.path)
    }

    @objc private func openVRoidHub() {
        Logger.log(event: .openVRoidHub)
        Logger.log("")
        UniBridge.shared.openVRoidHub()
    }
}

// MARK: - Object
private extension AppMenu {
    private func setupObjectMenu(subMenu: NSMenu) {
        Self.makeSubMenu(menu: subMenu, title: L10n.object.text, items: [
            makeMenuItem(title: L10n.resetAvatarPosition.text, action: #selector(resetAvatarPosition)),
            .separator(),
            makeMenuItem(title: L10n.addImage.text, action: #selector(addImage)),
            makeMenuItem(title: L10n.addScreenCapture.text, action: #selector(addScreenCapture)),
            makeMenuItem(title: L10n.addVideoCapture.text, action: #selector(addVideoCapture)),
            makeMenuItem(title: L10n.addWeb.text, action: #selector(addWeb)),
            .separator(),
            makeMenuItem(title: L10n.addWind.text, action: #selector(addWind)),
        ])
    }

    @objc private func resetAvatarPosition() {
        UniBridge.shared.resetCamera()
    }

    @objc private func addImage() {
        guard let url = FileUtility.openFile(type: .image) else { return }
        SceneObjectManager.shared.addImage(url: url)
    }

    @objc private func addScreenCapture() {
        showScreenRecorderPreferenceView { recorder in
            guard let config = recorder.captureConfig, let screenId = config.id else { return }
            let id = RenderTextureManager.shared.add(recorder)
            SceneObjectManager.shared.add(.init(id: id, type: .screen(.init(id: screenId, captureType: config.captureType.type, textureSize: recorder.size, crop: recorder.cropRect, filter: nil)), isHidden: false, isLocked: false))
        }
    }

    @objc private func addVideoCapture() {
        CaptureDeviceRenderer.selectDevice { drawer in
            let id = RenderTextureManager.shared.add(drawer)
            SceneObjectManager.shared.add(.init(id: id, type: .videoCapture(.init(id: drawer.id, textureSize: drawer.size, crop: drawer.cropRect, filter: nil)), isHidden: false, isLocked: false))
        }
    }

    @objc private func addWeb() {
        WebRenderer.showPreferencesForAdding()
    }

    @objc private func addWind() {
        SceneObjectManager.shared.add(.init(type: .wind(), isHidden: false, isLocked: false))
    }
}

// MARK: - Avatar
private extension AppMenu {
    private func setupAvatarMenu(subMenu: NSMenu) {
        Self.makeSubMenu(menu: subMenu, title: L10n.avatar.text, items: [
            makeMenuItem(title: L10n.editAvatar.text, action: #selector(editAvatar)),
            .separator(),
            makeMenuItem(title: L10n.calibrate.text, action: #selector(resetCalibration)),
        ])
    }

    @objc private func editAvatar() {
        Logger.log("")
        UniBridge.shared.editAvatar()
    }

    @objc private func resetCalibration() {
        Tracking.shared.resetCalibration()
    }
}

// MARK: - Window
private extension AppMenu {
    private func setupWindowMenu(subMenu: NSMenu) {
        let alwaysOnTop = makeMenuItem(title: L10n.alwaysOnTop.text, action: #selector(toggleAlwaysOnTop))
        alwaysOnTop.state = UserDefaults.standard.value(for: .alwaysOnTopEnabled) ? .on : .off
        Self.makeSubMenu(menu: subMenu, title: L10n.window.text, items: [
            alwaysOnTop,
        ])
    }

    @objc private func toggleAlwaysOnTop(_ sender: NSMenuItem) {
        let enabled = !UserDefaults.standard.value(for: .alwaysOnTopEnabled)
        VCamSystem.shared.windowManager.setAlwaysOnTopEnabled(enabled)
        sender.state = enabled ? .on : .off
    }
}

// MARK: - Help
private extension AppMenu {
    private func setupHelpMenu(subMenu: NSMenu) {
        Self.makeSubMenu(menu: subMenu, title: L10n.help.text, items: [
            makeMenuItem(title: L10n.anyProblem.text, action: #selector(help)),
        ])
    }

    @objc private func help() {
        let url = URL(string: "https://tattn.gitbook.io/vcam/sono-others/sono/faq")!
        NSWorkspace.shared.open(url)
    }
}
