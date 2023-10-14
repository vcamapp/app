//
//  UserDefaultsKey.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/04/23.
//

import Foundation
import VCamDefaults
import VCamEntity

public extension UserDefaults.Key {
    typealias Key = UserDefaults.Key
    static var skipThisVersion: Key<Version> { .init("vc_skip_version", default: "0.0.0") }
    static var previousVersion: Key<String> { .init("vc_prev_version", default: "") }
    static var useHMirror: Key<Bool> { .init("vc_use_hmirror", default: false) }
    static var useAutoConvertVRM1: Key<Bool> { .init("vc_use_auto_convert_vrm1", default: false) }
    static var useVowelEstimation: Key<Bool> { .init("vc_use_vowel_estimation", default: false) }
    static var useEyeTracking: Key<Bool> { .init("vc_use_eye_tracking", default: true) }
    static var useEmotion: Key<Bool> { .init("vc_use_emotion", default: false) }
    static var cameraFps: Key<Int> { .init("vc_camera_fps", default: 24) }
    static var captureDeviceId: Key<String?> { .init("vc_capture_device_id", default: nil) }
    static var audioDeviceUid: Key<String?> { .init("vc_audio_device_uid", default: nil) }
    static var locale: Key<String> { .init("vc_locale", default: "") }
    static var pluginVersion: Key<String> { .init("vc_plugin_ver", default: "") }
    static var alwaysOnTopEnabled: Key<Bool> { .init("vc_alwaysontop_enabled", default: false) }
    static var trackingMethodFace: Key<TrackingMethod.Face> { .init("vc_tracking_method_face", default: .default) }
    static var trackingMethodHand: Key<TrackingMethod.Hand> { .init("vc_tracking_method_hand", default: .default) }
    static var trackingMethodFinger: Key<TrackingMethod.Finger> { .init("vc_tracking_method_finger", default: .default) }
    static var moveXIntensity: Key<Double> { .init("vc_move_x_intensity", default: 1) }
    static var eyeTrackingOffsetY: Key<Double> { .init("vc_eye_tracking_offset_y", default: -0.2) }
    static var eyeTrackingIntensityX: Key<Double> { .init("vc_eye_tracking_intensity_x", default: 6) }
    static var eyeTrackingIntensityY: Key<Double> { .init("vc_eye_tracking_intensity_y", default: 3) }
    static var fingerTrackingOpenIntensity: Key<Double> { .init("vc_ftracking_open_intensity", default: 1) }
    static var fingerTrackingCloseIntensity: Key<Double> { .init("vc_ftracking_close_intensity", default: 1) }
    static var screenshotWaitTime: Key<Double> { .init("vc_screenshot_wait", default: 0) }
    static var screenshotDestination: Key<Data> { .init("vc_screenshot_dest", default: .init()) }
    static var recordingVideoFormat: Key<String> { .init("vc_rec_videoformat", default: "mp4") }
    static var recordSystemSound: Key<Bool> { .init("vc_rec_systemsound", default: false) }
    static var recordMicSyncOffset: Key<Int> { .init("vc_rec_mic_sync_offset", default: -160) }
    static var integrationVCamMocap: Key<Bool> { .init("vc_intg_vcammocap", default: false) }
    static var integrationFacialMocapIp: Key<String> { .init("vc_intg_facialmocap_ip", default: "192.168.0.1") }
    static var integrationMocopi: Key<Bool> { .init("vc_intg_mocopi", default: false) }

    static var macOSMicModeEnabled: Key<Bool> { .init("vc_macos_micmode_enabled", default: false) }
}
