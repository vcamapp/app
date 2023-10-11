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

public final class VCamSystem {
    public let pasteboardObserver = PasteboardObserver()

    public private(set) var isStarted = false
    public var isUniVCamSystemEnabled = false

    init() {
        ExtensionNotificationCenter.default.setObserver(for: .startCameraExtensionStream) { [weak self] in
            self?.startSystem()
        }

        ExtensionNotificationCenter.default.setObserver(for: .stopAllCameraExtensionStreams) { [weak self] in
            self?.stopSystem()
        }
    }

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
        Logger.log("\(isStarted), \(WindowManager.shared.isWindowClosed)")
        guard isStarted, WindowManager.shared.isWindowClosed else { return }
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
