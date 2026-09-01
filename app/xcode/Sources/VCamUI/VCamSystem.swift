import AppKit
import VCamBridge
import VCamControl
#if FEATURE_API
import VCamRemoteControl
#endif
import VCamTracking
import VCamLogger
import VCamCamera
import VCamData
import VCamEntity

@MainActor
public final class VCamSystem {
    public static let shared = VCamSystem()
    public static var initializeToEngine: (() -> Void)?

    /// Whether this build is the distributed product. A build that only hosts the UI sets it to
    /// false so that it does not act on behalf of the installed app.
    /// Must be set before the first access to `shared`
    public static var isDistributedApp = true

    public let windowManager = WindowManager()

    public private(set) var isStarted = false
    public var isUniVCamSystemEnabled = false {
        didSet {
            windowManager.window?.backgroundColor = isUniVCamSystemEnabled ? .clear : .windowBackgroundColor
        }
    }

    private init() {
        SceneControl.provider = SceneManager.shared

        VirtualCamera.onConsumersChanged = { [weak self] hasConsumers in
            Task { @MainActor in
                if hasConsumers {
                    self?.startSystem()
                } else {
                    self?.stopSystem()
                }
            }
        }

        UniState.shared.initializeToEngine()
        Self.initializeToEngine?()
        Workaround.fixColorPickerOpacity_macOS14()
        windowManager.setUpWindow()
        windowManager.setUpView()
        AppMenu.shared.configure()

        if Self.isDistributedApp, !UniBridge.isEngineApp {
            AppUpdater.vcam.presentUpdateAlertIfAvailable()
        }

        Camera.configure()
        AudioDevice.configure()

        Task { @MainActor in
            if Self.isDistributedApp {
                await Migration.migrate()
            }
            // Runs for every build: connecting only requires an already installed virtual camera
            VirtualCamera.backend?.start()
        }
    }

    public func configure() {
        guard UniBridge.isEngineApp else { return }
        windowManager.window?.orderFront(nil)
    }

    public func startSystem() {
        Logger.log("\(isStarted)")
        guard !isStarted else { return }
        isStarted = true
        Tracking.shared.configure()
        RenderTextureManager.shared.resume()
        PasteboardObserver.shared.observe()
#if FEATURE_API
        ExternalControlServer.shared.startIfEnabled()
#endif
        UniBridge.shared.resumeApp()
    }

    public func stopSystem() {
        Logger.log("\(isStarted), \(windowManager.isWindowClosed)")
        guard isStarted, windowManager.isWindowClosed else { return }
        stopSubsystems()
        UniBridge.shared.pauseApp()
    }

    public func dispose() {
        stopSubsystems()
        UniBridge.shared.reset()
    }

    public func relaunch() {
        // Launch the new instance after this instance has exited to avoid conflicts over the virtual camera
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "while /bin/kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done; sleep 0.5; open -n \"$0\"", Bundle.main.bundlePath]
        try? process.run()
        if UniBridge.shared.triggerMapper.isRegistered {
            // While the bridge is attached, the app quits only through it
            UniBridge.shared.quitApp()
        } else {
            NSApp.terminate(nil)
        }
    }

    private func stopSubsystems() {
        isStarted = false
        Tracking.shared.stop()
        AvatarAudioManager.shared.stop(usage: .all)
        VideoRecorder.shared.stop()
        RenderTextureManager.shared.pause()
        PasteboardObserver.shared.dispose()
#if FEATURE_API
        ExternalControlServer.shared.stop()
#endif
    }
}

private extension UniBridge {
    func reset() {
        intMapper.reset()
        boolMapper.reset()
        arrayMapper.reset()
        floatMapper.reset()
        stringMapper.reset()
        structMapper.reset()
        triggerMapper.reset()
    }
}
