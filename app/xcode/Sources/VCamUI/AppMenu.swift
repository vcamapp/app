import Foundation
import AppKit
import VCamBridge
import VCamControl
import VCamData
import VCamTracking
import VCamLogger
import SystemExtensions
import VCamEntity
#if FEATURE_3
import VCamVRoidHub
#endif

@MainActor
public final class AppMenu: NSObject {
    public static let shared = AppMenu()

    public let menu: NSMenu

    private override init() {
        let mainMenu: NSMenu
        if UniBridge.isEngineApp {
            menu = Self.makeSubMenu(menu: NSApp.mainMenu!, title: "VCamMenu", items: [])
            mainMenu = NSApp.mainMenu!.items[0].submenu!
        } else {
            menu = NSMenu()
            mainMenu = Self.makeSubMenu(menu: menu, title: Bundle.main.displayName, items: [])
            NSApp.mainMenu = menu
            // AppKit would otherwise add the tab items to the Window menu, for windows that never show tabs
            NSWindow.allowsAutomaticWindowTabbing = false
        }

        super.init()

        setupMainMenu(subMenu: mainMenu)
        setupFileMenu(subMenu: menu)
        setupEditMenu(subMenu: menu)
        setupObjectMenu(subMenu: menu)
#if FEATURE_3
        setupModelMenu(subMenu: menu)
#endif
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
        var items: [NSMenuItem] = [
            NSMenuItem(title: String(localized: .cut), action: #selector(NSText.cut(_:)), keyEquivalent: "x"),
            NSMenuItem(title: String(localized: .copy), action: #selector(NSText.copy(_:)), keyEquivalent: "c"),
            NSMenuItem(title: String(localized: .paste), action: #selector(NSText.paste(_:)), keyEquivalent: "v"),
            NSMenuItem(title: String(localized: .selectAll), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"),
        ]
        if !UniBridge.isEngineApp {
            let redo = NSMenuItem(title: String(localized: .redo), action: Selector(("redo:")), keyEquivalent: "z")
            redo.keyEquivalentModifierMask = [.command, .shift]
            items.insert(contentsOf: [
                NSMenuItem(title: String(localized: .undo), action: Selector(("undo:")), keyEquivalent: "z"),
                redo,
                .separator(),
            ], at: 0)
        }
        Self.makeSubMenu(menu: subMenu, title: String(localized: .edit), items: items)
    }
}

// MARK: - Main
private extension AppMenu {
    private func setupMainMenu(subMenu: NSMenu) {
        var items: [NSMenuItem] = [
            makeMenuItem(title: String(localized: .aboutApp(Bundle.main.displayName)), action: #selector(about)),
            makeMenuItem(title: String(localized: .settings), action: #selector(openPreferences), keyEquivalent: ","),
            .separator(),
            makeMenuItem(title: String(localized: .checkForUpdates), action: #selector(checkUpdates)),
            .separator(),
        ]
        // The engine's own application menu already has the services and hide items
        if !UniBridge.isEngineApp {
            items += makeSystemItems()
        }
        items.append(makeMenuItem(title: String(localized: .quitVCam(Bundle.main.displayName)), action: #selector(quit), keyEquivalent: "q"))
        subMenu.items.insert(contentsOf: items, at: 0)
    }

    private func makeSystemItems() -> [NSMenuItem] {
        let servicesItem = NSMenuItem(title: String(localized: .services), action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: servicesItem.title)
        servicesItem.submenu = servicesMenu
        NSApp.servicesMenu = servicesMenu

        let hideOthers = NSMenuItem(title: String(localized: .hideOthers), action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]

        return [
            servicesItem,
            .separator(),
            NSMenuItem(title: String(localized: .hideApp(Bundle.main.displayName)), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"),
            hideOthers,
            NSMenuItem(title: String(localized: .showAll), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""),
            .separator(),
        ]
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
        var items: [NSMenuItem] = [
            makeMenuItem(title: String(localized: .openModelList), action: #selector(openModelList)),
        ]
#if FEATURE_3
        if VRoidHub.isAvailable {
            items.append(contentsOf: [
                .separator(),
                makeMenuItem(title: String(localized: .loadOnVRoidHub), action: #selector(openVRoidHub)),
            ])
        }
#endif
        Self.makeSubMenu(menu: subMenu, title: String(localized: .file), items: items)
    }

    @objc private func openModelList() {
        Logger.log("")
        MacWindowManager.shared.open(ModelListView())
    }

#if FEATURE_3
    @objc private func openVRoidHub() {
        Logger.log(event: .openVRoidHub)
        Logger.log("")
        VRoidHubView.openWindow()
    }
#endif
}

// MARK: - Object
private extension AppMenu {
    private func setupObjectMenu(subMenu: NSMenu) {
        var items: [NSMenuItem] = []
#if !FEATURE_3
        items.append(makeMenuItem(title: String(localized: .resetModelPosition), action: #selector(resetModelPosition)))
        items.append(.separator())
#endif
        for object in AddableSceneObject.available {
            if object.startsNewSection {
                items.append(.separator())
            }
            let item = makeMenuItem(title: object.menuTitle, action: #selector(addObject(_:)))
            item.tag = object.rawValue
            items.append(item)
        }
        Self.makeSubMenu(menu: subMenu, title: String(localized: .object), items: items)
    }

    @objc private func addObject(_ sender: NSMenuItem) {
        AddableSceneObject(rawValue: sender.tag)?.perform()
    }
}

// MARK: - Model
private extension AppMenu {
    private func setupModelMenu(subMenu: NSMenu) {
        Self.makeSubMenu(menu: subMenu, title: String(localized: .model), items: [
            makeMenuItem(title: String(localized: .editModel), action: #selector(editModel)),
            makeMenuItem(title: String(localized: .editPose), action: #selector(editPose)),
            .separator(),
            makeMenuItem(title: String(localized: .calibrate), action: #selector(resetCalibration)),
            makeMenuItem(title: String(localized: .resetModelPosition), action: #selector(resetModelPosition)),
        ])
    }

    @objc private func editModel() {
        Logger.log("")
        MacWindowManager.shared.openAvatarEditor()
    }

    @objc private func editPose() {
        Logger.log("")
        MacWindowManager.shared.openPoseEditor()
    }

    @objc private func resetCalibration() {
        Tracking.shared.resetCalibration()
    }

    @objc private func resetModelPosition() {
        CameraControl.resetCamera()
    }
}

// MARK: - Window
private extension AppMenu {
    private func setupWindowMenu(subMenu: NSMenu) {
        let alwaysOnTop = makeMenuItem(title: String(localized: .alwaysOnTop), action: #selector(toggleAlwaysOnTop))
        alwaysOnTop.state = UserDefaults.standard.value(for: .alwaysOnTopEnabled) ? .on : .off
        var items: [NSMenuItem] = [
            alwaysOnTop,
            .separator(),
            makeMenuItem(title: String(localized: .resetWindowSize), action: #selector(resetWindowSize)),
        ]
        if !UniBridge.isEngineApp {
            items.insert(contentsOf: [
                NSMenuItem(title: String(localized: .minimize), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"),
                NSMenuItem(title: String(localized: .zoom), action: #selector(NSWindow.performZoom(_:)), keyEquivalent: ""),
                .separator(),
            ], at: 0)
            items += [
                .separator(),
                NSMenuItem(title: String(localized: .bringAllToFront), action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: ""),
            ]
        }
        let windowMenu = Self.makeSubMenu(menu: subMenu, title: String(localized: .window), items: items)
        if !UniBridge.isEngineApp {
            NSApp.windowsMenu = windowMenu
        }
    }

    @objc private func toggleAlwaysOnTop(_ sender: NSMenuItem) {
        let enabled = !UserDefaults.standard.value(for: .alwaysOnTopEnabled)
        VCamSystem.shared.windowManager.setAlwaysOnTopEnabled(enabled)
        sender.state = enabled ? .on : .off
    }

    @objc private func resetWindowSize() {
        VCamSystem.shared.windowManager.resetWindowSize()
    }
}

// MARK: - Help
private extension AppMenu {
    private func setupHelpMenu(subMenu: NSMenu) {
        let helpMenu = Self.makeSubMenu(menu: subMenu, title: String(localized: .help), items: [
            makeMenuItem(title: String(localized: .viewDocumentation), action: #selector(help)),
        ])
        if !UniBridge.isEngineApp {
            NSApp.helpMenu = helpMenu
        }
    }

    @objc private func help() {
        let url = URL(string: String(localized: .docsURL))!
        NSWorkspace.shared.open(url)
    }
}
