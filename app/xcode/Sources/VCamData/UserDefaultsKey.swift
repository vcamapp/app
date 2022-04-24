//
//  UserDefaultsKey.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/04/23.
//

import Foundation
import VCamEntity

public extension UserDefaults.Key {
    typealias Key = UserDefaults.Key
    static var skipThisVersion: Key<Version> { .init("vc_skip_version", default: "0.0.0") }
}
