//
//  Bundle+.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/04/23.
//

import Foundation

public extension Bundle {
    var version: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    var build: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    }

    var displayName: String {
        object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? "VCam"
    }
}
