//
//  VCamSystem.swift
//
//
//  Created by Tatsuya Tanaka on 2023/02/25.
//

import Foundation
import VCamAppExtension
import VCamBridge
import VCamTracking
import VCamLogger
import VCamCamera
import VCamEntity
import VCamWorkaround

public final class VCamSystem {
    public static let shared = VCamSystem()

    public let windowManager = WindowManager()
    public let pasteboardObserver = PasteboardObserver()

    public private(set) var isStarted = false
    public var isUniVCamSystemEnabled = false

    private init() {
        ExtensionNotificationCenter.default.setObserver(for: .startCameraExtensionStream) { [weak self] in
            self?.startSystem()
        }

        ExtensionNotificationCenter.default.setObserver(for: .stopAllCameraExtensionStreams) { [weak self] in
            self?.stopSystem()
        }

        Workaround.fixColorPickerOpacity_macOS14()
        windowManager.setUpWindow()

        Task { @MainActor in
            if !windowManager.isUnity {
#if DEBUG
                if !ProcessInfo.processInfo.arguments.contains("UITesting") {
                    await AppUpdater.vcam.presentUpdateAlertIfAvailable()
                }
#else
                await AppUpdater.vcam.presentUpdateAlertIfAvailable()
#endif
            }

            await Migration.migrate()
            windowManager.setUpView()
            AppMenu.shared.configure()

            Camera.configure()
            AudioDevice.configure()

            VirtualCameraManager.shared.startCameraExtension()
        }
    }

    public func configure() {}

    public func startSystem() {
        Logger.log("\(isStarted)")
        guard !isStarted else { return }
        isStarted = true
        Tracking.shared.configure()
        AvatarAudioManager.shared.startIfNeeded()
        RenderTextureManager.shared.resume()
        pasteboardObserver.observe()
        UniBridge.shared.resumeApp()
    }

    public func stopSystem() {
        Logger.log("\(isStarted), \(windowManager.isWindowClosed)")
        guard isStarted, windowManager.isWindowClosed else { return }
        isStarted = false
        Tracking.shared.stop()
        AvatarAudioManager.shared.stop(usage: .all)
        VideoRecorder.shared.stop()
        RenderTextureManager.shared.pause()
        pasteboardObserver.dispose()
        UniBridge.shared.pauseApp()
    }

    public func dispose() {
        isStarted = false
        Tracking.shared.stop()
        AvatarAudioManager.shared.stop(usage: .all)
        VideoRecorder.shared.stop()
        RenderTextureManager.shared.pause()
        pasteboardObserver.dispose()
        UniBridge.shared.reset()
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
