//
//  VCamSystem.swift
//
//
//  Created by Tatsuya Tanaka on 2023/02/25.
//

import AppKit
import VCamAppExtension
import VCamBridge
import VCamTracking
import VCamLogger
import VCamCamera
import VCamData
import VCamEntity
import VCamWorkaround

public final class VCamSystem {
    public static let shared = VCamSystem()
    public static var initializeToUnity: (() -> Void)?

    public let windowManager = WindowManager()

    public private(set) var isStarted = false
    public var isUniVCamSystemEnabled = false {
        didSet {
            NSApp.vcamWindow?.backgroundColor = isUniVCamSystemEnabled ? .clear : .windowBackgroundColor
        }
    }

    private init() {
        ExtensionNotificationCenter.default.setObserver(for: .startCameraExtensionStream) { [weak self] in
            self?.startSystem()
        }

        ExtensionNotificationCenter.default.setObserver(for: .stopAllCameraExtensionStreams) { [weak self] in
            self?.stopSystem()
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
        NSApp.vcamWindow?.orderFront(nil)
    }

    public func startSystem() {
        Logger.log("\(isStarted)")
        guard !isStarted else { return }
        isStarted = true
        Tracking.shared.configure()
        AvatarAudioManager.shared.startIfNeeded()
        RenderTextureManager.shared.resume()
        PasteboardObserver.shared.observe()
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
        PasteboardObserver.shared.dispose()
        UniBridge.shared.pauseApp()
    }

    public func dispose() {
        isStarted = false
        Tracking.shared.stop()
        AvatarAudioManager.shared.stop(usage: .all)
        VideoRecorder.shared.stop()
        RenderTextureManager.shared.pause()
        PasteboardObserver.shared.dispose()
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
