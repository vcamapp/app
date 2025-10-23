//
//  WindowManager.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/03/12.
//

import AppKit
import VCamLogger
import VCamCamera
import VCamBridge

public final class WindowManager: ObservableObject {
    @Published public private(set) var size = NSSize(width: 1280, height: 720)

    public let isUnity = Bundle.main.bundlePath.hasSuffix("Unity.app")

    public private(set) var isConfigured = false
    public fileprivate(set) var isWindowClosed = false
    public var isEnabled = false

    private let containerView = VCamRootContainerView()
    private var statusItem: NSStatusItem?

    public var isMacOSMenubarVisible: Bool {
        get { statusItem?.isVisible ?? false }
        set { statusItem?.isVisible = newValue }
    }

    init() {
        NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: nil, queue: .main) { _ in
            if let size = NSApp.mainWindow?.contentView?.frame.size {
                DispatchQueue.main.async {
                    self.size = size
                }
            }
        }

        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            // Display the window when launching the app while it's stored in the menu bar.
            VCamSystem.shared.windowManager.unhide()
        }
    }

    public func setUpWindow() {
        Logger.log("")

        if isUnity, !NSApp.windows.map(\.title).contains("VCam") {
            uniDebugLog("WindowManager.setUpWindow()")
            let windowRef = NSWindow()
            windowRef.title = "VCam"
            windowRef.styleMask = [.titled, .closable, .resizable]
            windowRef.backingType = .buffered
            windowRef.level = .floating
            windowRef.isReleasedWhenClosed = false
            windowRef.setFrameAutosaveName("UnityPlayerVCamUI")
            windowRef.makeKeyAndOrderFront(nil)
        } else if let window = NSApp.mainOrFirstWindow {
            window.appearance = NSAppearance(named: .darkAqua)
            window.title = "VCam"
            window.titlebarAppearsTransparent = true
//            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
            window.styleMask = [
                .titled,
                .closable,
                .miniaturizable,
                .resizable,
                .fullSizeContentView,
            ]
            window.titleVisibility = .visible
            window.minSize = .init(width: 800, height: 450)
            window.contentAspectRatio = NSSize(width: 1280, height: 720)
        }
    }

    public func setUpView() {
        Logger.log("")

        defer {
            isConfigured = true
        }

        guard !isConfigured, containerView.subviews.isEmpty, let window = NSApp.vcamWindow, let unityView = window.contentView else {
            return
        }

        containerView.addFilledView(RootView(unityView: {
            if isUnity {
                return NSView()
            } else {
                NSLayoutConstraint.deactivate(unityView.constraints)
                unityView.removeFromSuperview()
                unityView.translatesAutoresizingMaskIntoConstraints = false
                return unityView
            }
        }()))
        window.contentView = containerView

        if isUnity {
            uniDebugLog("WindowManager.setUpView()")
            window.setContentSize(containerView.fittingSize)
        } else {
            setupMenuBar()
            setAlwaysOnTopEnabled(UserDefaults.standard.value(for: .alwaysOnTopEnabled))
        }
    }

    public func setupMenuBar() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.statusItem = statusItem
        statusItem.button?.image = Bundle.module.image(forResource: "StatusItemIcon")
        let menu = NSMenu()
        let unhideMenu = NSMenuItem(title: "\(L10n.openVCam.text)...", action: #selector(unhide), keyEquivalent: "")
        unhideMenu.target = self
        menu.addItem(unhideMenu)
        let preferenceMenu = NSMenuItem(title: "\(L10n.settings.text)...", action: #selector(openPreferences), keyEquivalent: "")
        preferenceMenu.target = self
        menu.addItem(preferenceMenu)
        menu.addItem(NSMenuItem.separator())
        let quitMenu = NSMenuItem(title: L10n.quitVCam.text, action: #selector(quit), keyEquivalent: "q")
        quitMenu.target = self
        menu.addItem(quitMenu)

//        let menuItemView = NSHostingView(rootView: MacMenuBarIcon())
//        menuItemView.frame.size = .init(width: 320, height: 280)
//        let menuItem = NSMenuItem()
//        menuItem.view = menuItemView
//        menu.addItem(menuItem)

        statusItem.menu = menu

        statusItem.isVisible = UniBridge.shared.useAddToMacOSMenuBar.wrappedValue
    }

    @objc public func hide() {
        guard !isWindowClosed else { return }
        isWindowClosed = true
        NSApp.vcamWindow?.setIsVisible(false)
        NSApp.setActivationPolicy(.accessory)
        if VirtualCameraManager.shared.sinkStream.streamingCount() == 0 {
            VCamSystem.shared.stopSystem()
        }
    }

    @objc public func unhide() {
        guard isWindowClosed else { return }
        isWindowClosed = false
        NSApp.setActivationPolicy(.regular)
        NSApp.vcamWindow?.setIsVisible(true)
        NSApp.activate(ignoringOtherApps: true)
        VCamSystem.shared.startSystem()
    }

    public func dispose() {
        Logger.log("")
        VCamSystem.shared.dispose()
        isConfigured = false

        if isUnity {
            uniDebugLog("WindowManager.dispose()")
            SceneObjectManager.shared.dispose()
            NSApp.vcamWindow?.orderOut(nil)
        } else {
            NSApp.stop(nil)
        }
    }

    public func setAlwaysOnTopEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, for: .alwaysOnTopEnabled)
        NSApp.vcamWindow?.level = enabled ? .floating : .normal
    }

    @objc public func quit() {
        UniBridge.shared.quitApp()
    }

    @objc private func openPreferences() {
        MacWindowManager.shared.open(VCamSettingView())
    }
}
