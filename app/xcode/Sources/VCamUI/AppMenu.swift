import Foundation
import AppKit
import VCamUIFoundation
import VCamBridge
import VCamData
import VCamCamera
import VCamTracking
import VCamLogger
import SystemExtensions

@MainActor
public final class AppMenu: NSObject {
    public static let shared = AppMenu()

    public let menu: NSMenu

    private override init() {
        let mainMenu: NSMenu
        if UniBridge.isUnity {
            menu = Self.makeSubMenu(menu: NSApp.mainMenu!, title: "VCamMenu", items: [])
            mainMenu = NSApp.mainMenu!.items[0].submenu!
        } else {
            menu = NSMenu()
            mainMenu = Self.makeSubMenu(menu: menu, title: Bundle.main.displayName, items: [])
            NSApp.mainMenu = menu
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
        Self.makeSubMenu(menu: subMenu, title: String(localized: .edit), items: [
            NSMenuItem(title: String(localized: .cut), action: #selector(NSText.copy(_:)), keyEquivalent: "x"),
            NSMenuItem(title: String(localized: .copy), action: #selector(NSText.copy(_:)), keyEquivalent: "c"),
            NSMenuItem(title: String(localized: .paste), action: #selector(NSText.paste(_:)), keyEquivalent: "v"),
            NSMenuItem(title: String(localized: .selectAll), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"),
        ])
    }
}

// MARK: - Main
private extension AppMenu {
    private func setupMainMenu(subMenu: NSMenu) {
        let quitItem = makeMenuItem(title: String(localized: .quitVCam(Bundle.main.displayName)), action: #selector(quit), keyEquivalent: "q")
        subMenu.items.insert(quitItem, at: 0)
        subMenu.items.insert(.separator(), at: 0)
        let updateItem = makeMenuItem(title: String(localized: .checkForUpdates), action: #selector(checkUpdates))
        subMenu.items.insert(updateItem, at: 0)
        subMenu.items.insert(.separator(), at: 0)
        let preferenceItem = makeMenuItem(title: String(localized: .settings), action: #selector(openPreferences), keyEquivalent: ",")
        subMenu.items.insert(preferenceItem, at: 0)
        let aboutItem = makeMenuItem(title: String(localized: .aboutApp(Bundle.main.displayName)), action: #selector(about))
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
        var items: [NSMenuItem] = [
            makeMenuItem(title: String(localized: .openModelList), action: #selector(openModelList)),
        ]
#if FEATURE_3
        items.append(contentsOf: [
            .separator(),
            makeMenuItem(title: String(localized: .loadOnVRoidHub), action: #selector(openVRoidHub)),
        ])
#endif
        Self.makeSubMenu(menu: subMenu, title: String(localized: .file), items: items)
    }

    @objc private func openModelList() {
        Logger.log("")
        MacWindowManager.shared.open(ModelListView())
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
#if FEATURE_3
        let items: [NSMenuItem] = [
            makeMenuItem(title: String(localized: .addImage), action: #selector(addImage)),
            makeMenuItem(title: String(localized: .addScreenCapture), action: #selector(addScreenCapture)),
            makeMenuItem(title: String(localized: .addVideoCapture), action: #selector(addVideoCapture)),
            makeMenuItem(title: String(localized: .addWeb), action: #selector(addWeb)),
            .separator(),
            makeMenuItem(title: String(localized: .addWind), action: #selector(addWind)),
        ]
#else
        let items: [NSMenuItem] = [
            makeMenuItem(title: String(localized: .resetModelPosition), action: #selector(resetModelPosition)),
            .separator(),
            makeMenuItem(title: String(localized: .addImage), action: #selector(addImage)),
            makeMenuItem(title: String(localized: .addScreenCapture), action: #selector(addScreenCapture)),
            makeMenuItem(title: String(localized: .addVideoCapture), action: #selector(addVideoCapture)),
            makeMenuItem(title: String(localized: .addWeb), action: #selector(addWeb)),
        ]
#endif
        Self.makeSubMenu(menu: subMenu, title: String(localized: .object), items: items)
    }

    @objc private func addImage() {
        guard let url = FileUtility.openFile(type: .image) else { return }
        SceneObjectManager.shared.addImage(url: url)
    }

    @objc private func addScreenCapture() {
        showScreenRecorderPreferenceView { recorder in
            SceneObjectManager.shared.addScreenCapture(recorder)
        }
    }

    @objc private func addVideoCapture() {
        CaptureDeviceRenderer.selectDevice { drawer in
            SceneObjectManager.shared.addVideoCapture(drawer)
        }
    }

    @objc private func addWeb() {
        WebRenderer.showPreferencesForAdding()
    }

    @objc private func addWind() {
        SceneObjectManager.shared.add(.init(type: .wind(), isHidden: false, isLocked: false))
    }
}

// MARK: - Model
private extension AppMenu {
    private func setupModelMenu(subMenu: NSMenu) {
        Self.makeSubMenu(menu: subMenu, title: String(localized: .model), items: [
            makeMenuItem(title: String(localized: .editModel), action: #selector(editModel)),
            .separator(),
            makeMenuItem(title: String(localized: .calibrate), action: #selector(resetCalibration)),
            makeMenuItem(title: String(localized: .resetModelPosition), action: #selector(resetModelPosition)),
        ])
    }

    @objc private func editModel() {
        Logger.log("")
        UniBridge.shared.editAvatar()
    }

    @objc private func resetCalibration() {
        Tracking.shared.resetCalibration()
    }

    @objc private func resetModelPosition() {
        UniBridge.shared.resetCamera()
    }
}

// MARK: - Window
private extension AppMenu {
    private func setupWindowMenu(subMenu: NSMenu) {
        let alwaysOnTop = makeMenuItem(title: String(localized: .alwaysOnTop), action: #selector(toggleAlwaysOnTop))
        alwaysOnTop.state = UserDefaults.standard.value(for: .alwaysOnTopEnabled) ? .on : .off
        Self.makeSubMenu(menu: subMenu, title: String(localized: .window), items: [
            alwaysOnTop,
            .separator(),
            makeMenuItem(title: String(localized: .resetWindowSize), action: #selector(resetWindowSize)),
        ])
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
        Self.makeSubMenu(menu: subMenu, title: String(localized: .help), items: [
            makeMenuItem(title: String(localized: .viewDocumentation), action: #selector(help)),
        ])
    }

    @objc private func help() {
        let url = URL(string: "https://docs.vcamapp.com/")!
        NSWorkspace.shared.open(url)
    }
}
