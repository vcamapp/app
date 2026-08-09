import AppKit
import VCamAppExtension
import VCamBridge
import VCamTracking
import VCamLogger
import VCamCamera
import VCamData
import VCamEntity

@MainActor
public final class VCamSystem {
    public static let shared = VCamSystem()
    public static var initializeToUnity: (() -> Void)?

    public let windowManager = WindowManager()

    public private(set) var isStarted = false
    public var isUniVCamSystemEnabled = false {
        didSet {
            windowManager.window?.backgroundColor = isUniVCamSystemEnabled ? .clear : .windowBackgroundColor
        }
    }

    private init() {
        ExtensionNotificationCenter.default.setObserver(for: .startCameraExtensionStream) { [weak self] in
            Task { @MainActor in
                self?.startSystem()
            }
        }

        ExtensionNotificationCenter.default.setObserver(for: .stopAllCameraExtensionStreams) { [weak self] in
            Task { @MainActor in
                self?.stopSystem()
            }
        }

        UniState.shared.initializeToUnity()
        Self.initializeToUnity?()
        Workaround.fixColorPickerOpacity_macOS14()
        windowManager.setUpWindow()
        windowManager.setUpView()
        AppMenu.shared.configure()

        if !UniBridge.isUnity {
            AppUpdater.vcam.presentUpdateAlertIfAvailable()
        }

        Camera.configure()
        AudioDevice.configure()

        Task { @MainActor in
            await Migration.migrate()

            VirtualCameraManager.shared.startCameraExtension()
        }
    }

    public func configure() {
        guard UniBridge.isUnity else { return }
        windowManager.window?.orderFront(nil)
    }

    public func startSystem() {
        Logger.log("\(isStarted)")
        guard !isStarted else { return }
        isStarted = true
        Tracking.shared.configure()
        RenderTextureManager.shared.resume()
        PasteboardObserver.shared.observe()
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
