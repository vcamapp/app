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
import VCamData

@MainActor
@Observable
public final class WindowManager {
    public private(set) var size = NSSize(width: 1280, height: 720)

    @ObservationIgnored public private(set) var isConfigured = false
    @ObservationIgnored public fileprivate(set) var isWindowClosed = false
    @ObservationIgnored public var isEnabled = false

    private let containerView = VCamRootContainerView()
    @ObservationIgnored private var statusItem: NSStatusItem?

    @ObservationIgnored public var isMacOSMenubarVisible: Bool {
        get { statusItem?.isVisible ?? false }
        set { statusItem?.isVisible = newValue }
    }

    init() {
        NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if let size = NSApp.mainWindow?.contentView?.frame.size {
                    self.size = size
                }
            }
        }

        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            // Display the window when launching the app while it's stored in the menu bar.
            MainActor.assumeIsolated {
                VCamSystem.shared.windowManager.unhide()
            }
        }
    }

    public func setUpWindow() {
        Logger.log("")

        if UniBridge.isUnity {
            uniDebugLog("WindowManager.setUpWindow()")
            let windowRef = NSWindow()
            windowRef.title = UniBridge.isUnity ? "VCam" : Bundle.main.displayName
            windowRef.styleMask = [.titled, .closable, .resizable]
            windowRef.backingType = .buffered
            windowRef.level = .floating
            windowRef.isReleasedWhenClosed = false
            windowRef.setFrameAutosaveName("UnityPlayerVCamUI")
            windowRef.makeKeyAndOrderFront(nil)
        } else if let window = NSApp.mainOrFirstWindow {
            window.appearance = NSAppearance(named: .darkAqua)
            window.title = Bundle.main.displayName
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
            window.collectionBehavior = [.fullScreenNone]
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
            if UniBridge.isUnity {
                return NSView()
            } else {
                NSLayoutConstraint.deactivate(unityView.constraints)
                unityView.removeFromSuperview()
                unityView.translatesAutoresizingMaskIntoConstraints = false
                return unityView
            }
        }()))
        window.contentView = containerView

        if UniBridge.isUnity {
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
        let unhideMenu = NSMenuItem(title: "\(L10n.openVCam(Bundle.main.displayName).text)...", action: #selector(unhide), keyEquivalent: "")
        unhideMenu.target = self
        menu.addItem(unhideMenu)
        let preferenceMenu = NSMenuItem(title: "\(L10n.settings.text)...", action: #selector(openPreferences), keyEquivalent: "")
        preferenceMenu.target = self
        menu.addItem(preferenceMenu)
        menu.addItem(NSMenuItem.separator())
        let quitMenu = NSMenuItem(title: L10n.quitVCam(Bundle.main.displayName).text, action: #selector(quit), keyEquivalent: "q")
        quitMenu.target = self
        menu.addItem(quitMenu)

//        let menuItemView = NSHostingView(rootView: MacMenuBarIcon())
//        menuItemView.frame.size = .init(width: 320, height: 280)
//        let menuItem = NSMenuItem()
//        menuItem.view = menuItemView
//        menu.addItem(menuItem)

        statusItem.menu = menu

        statusItem.isVisible = UniState.shared.useAddToMacOSMenuBar
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

        if UniBridge.isUnity {
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

    public func resetWindowSize() {
        guard let window = NSApp.vcamWindow else { return }
        let defaultSize = window.minSize
        window.setContentSize(defaultSize)
        size = defaultSize
    }

    @objc public func quit() {
        UniBridge.shared.quitApp()
    }

    @objc private func openPreferences() {
        MacWindowManager.shared.open(VCamSettingView())
    }
}
