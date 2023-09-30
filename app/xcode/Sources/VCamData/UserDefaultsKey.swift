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
    static var useVowelEstimation: Key<Bool> { .init("vc_use_vowel_estimation", default: false) }
    static var cameraFps: Key<Int> { .init("vc_camera_fps", default: 24) }
    static var locale: Key<String> { .init("vc_locale", default: "") }
    static var pluginVersion: Key<String> { .init("vc_plugin_ver", default: "") }
    static var alwaysOnTopEnabled: Key<Bool> { .init("vc_alwaysontop_enabled", default: false) }
    static var fingerTrackingOpenIntensity: Key<Double> { .init("vc_ftracking_open_intensity", default: 1) }
    static var fingerTrackingCloseIntensity: Key<Double> { .init("vc_ftracking_close_intensity", default: 1) }
}
