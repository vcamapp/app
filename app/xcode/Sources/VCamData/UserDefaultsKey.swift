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
    static var locale: Key<String> { .init("vc_locale", default: "") }
    static var pluginVersion: Key<String> { .init("vc_plugin_ver", default: "") }
}
