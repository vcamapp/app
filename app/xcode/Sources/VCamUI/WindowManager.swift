import AppKit
import VCamLogger
import VCamCamera
import VCamBridge
import VCamData

@MainActor
@Observable
public final class WindowManager {
    public private(set) var size = NSSize(width: 1280, height: 720)

    @ObservationIgnored public private(set) var window: NSWindow?
    @ObservationIgnored public private(set) var isConfigured = false
    @ObservationIgnored public fileprivate(set) var isWindowClosed = false

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

        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            // Display the window when launching the app while it's stored in the menu bar.
            // Use Task instead of assumeIsolated; the synchronous executor check of
            // assumeIsolated can crash in the runtime when activation races with app termination
            Task { @MainActor in
                self?.unhide()
            }
        }
    }

    public func setUpWindow() {
        Logger.log("")

        if UniBridge.isEngineApp {
            uniDebugLog("WindowManager.setUpWindow()")
            let windowRef = NSWindow()
            windowRef.title = "VCam"
            windowRef.styleMask = [.titled, .closable, .resizable]
            windowRef.backingType = .buffered
            windowRef.level = .floating
            windowRef.isReleasedWhenClosed = false
            // Persisted autosave key; renaming it would reset users' saved window frames
            windowRef.setFrameAutosaveName("UnityPlayerVCamUI")
            windowRef.makeKeyAndOrderFront(nil)
            self.window = windowRef
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
            self.window = window
        }
    }

    public func setUpView() {
        Logger.log("")

        guard !isConfigured, containerView.subviews.isEmpty, let window, let engineView = window.contentView else {
            return
        }

        containerView.addFilledView(RootView(engineView: {
            if UniBridge.isEngineApp {
                return NSView()
            } else {
                NSLayoutConstraint.deactivate(engineView.constraints)
                engineView.removeFromSuperview()
                engineView.translatesAutoresizingMaskIntoConstraints = false
                return engineView
            }
        }()))
        window.contentView = containerView

        if UniBridge.isEngineApp {
            uniDebugLog("WindowManager.setUpView()")
            window.setContentSize(containerView.fittingSize)
        } else {
            setupMenuBar()
            setAlwaysOnTopEnabled(UserDefaults.standard.value(for: .alwaysOnTopEnabled))
        }

        isConfigured = true
    }

    public func setupMenuBar() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.statusItem = statusItem
        statusItem.button?.image = Bundle.module.image(forResource: "StatusItemIcon")
        let menu = NSMenu()
        let unhideMenu = NSMenuItem(title: "\(String(localized: .openVCam(Bundle.main.displayName)))...", action: #selector(unhide), keyEquivalent: "")
        unhideMenu.target = self
        menu.addItem(unhideMenu)
        let preferenceMenu = NSMenuItem(title: "\(String(localized: .settings))...", action: #selector(openPreferences), keyEquivalent: "")
        preferenceMenu.target = self
        menu.addItem(preferenceMenu)
        menu.addItem(NSMenuItem.separator())
        let quitMenu = NSMenuItem(title: String(localized: .quitVCam(Bundle.main.displayName)), action: #selector(quit), keyEquivalent: "q")
        quitMenu.target = self
        menu.addItem(quitMenu)

        statusItem.menu = menu

        statusItem.isVisible = UniState.shared.useAddToMacOSMenuBar
    }

    @objc public func hide() {
        guard !isWindowClosed else { return }
        isWindowClosed = true
        window?.setIsVisible(false)
        NSApp.setActivationPolicy(.accessory)
        if VirtualCameraManager.shared.sinkStream.streamingCount() == 0 {
            VCamSystem.shared.stopSystem()
        }
    }

    @objc public func unhide() {
        guard isWindowClosed else { return }
        isWindowClosed = false
        NSApp.setActivationPolicy(.regular)
        window?.setIsVisible(true)
        NSApp.activate(ignoringOtherApps: true)
        VCamSystem.shared.startSystem()
    }

    public func dispose() {
        Logger.log("")
        VCamSystem.shared.dispose()
        isConfigured = false

        if UniBridge.isEngineApp {
            uniDebugLog("WindowManager.dispose()")
            SceneObjectManager.shared.dispose()
            window?.orderOut(nil)
        } else {
            NSApp.stop(nil)
        }
    }

    public func setAlwaysOnTopEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, for: .alwaysOnTopEnabled)
        window?.level = enabled ? .floating : .normal
    }

    public func resetWindowSize() {
        guard let window else { return }
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
