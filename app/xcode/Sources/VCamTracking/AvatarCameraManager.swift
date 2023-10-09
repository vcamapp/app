//
//  AvatarCameraManager.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/03/05.
//

import AVFoundation
import VCamCamera
import VCamBridge

public final class AvatarCameraManager {
    private let webCamera = AvatarWebCamera()

    public static var isCameraAuthorized: () -> Bool = { false }
    public static var requestCameraPermission: (@escaping (Bool) -> Void) -> Void = { _ in }

    public var currentCaptureDevice: AVCaptureDevice? { webCamera.currentCaptureDevice }
    public var webCameraUsage: AvatarWebCamera.Usage { webCamera.usage }
    public var finterConfiguration: FingerTrackingConfiguration { webCamera.handTracking.configuration }

    private var isWebCameraUsed: Bool {
        webCamera.usage.intersection([.faceTracking, .handTracking, .fingerTracking]) != .disabled
    }

    public var isBlinkerUsed: Bool {
        switch Tracking.shared.faceTrackingMethod {
        case .disabled:
            return true
        case .default, .iFacialMocap, .vcamMocap:
            return false
        }
    }

    private func start() {
        webCamera.isEmotionEnabled = UserDefaults.standard.value(for: .useEmotion)

        if Self.isCameraAuthorized() {
            webCamera.start()
        } else {
            Self.requestCameraPermission { [self] authorized in
                guard authorized else { return }
                webCamera.start()
            }
        }
    }

    func stop() {
        webCamera.stop()
    }

    func resetCalibration() {
        webCamera.resetCalibration()
    }

    public func setCaptureDevice(id: String?) {
        webCamera.setCaptureDevice(id: id)
    }

    public func setFPS(_ fps: Int) {
        webCamera.setFPS(fps)
    }

    public func setEmotionEnabled(_ isEnabled: Bool) {
        webCamera.isEmotionEnabled = isEnabled
        UserDefaults.standard.set(isEnabled, for: .useEmotion)
    }

    public func setWebCamUsage(_ usage: AvatarWebCamera.Usage) {
        webCamera.usage = usage
        if isWebCameraUsed {
            start()
        } else {
            stop()
        }
        UniBridge.shared.useBlinker(isBlinkerUsed)
    }
}
