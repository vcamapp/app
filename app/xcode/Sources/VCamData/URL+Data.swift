//
//  URL+Data.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/05/08.
//

import Foundation

public extension URL {
    static var applicationSupportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent(Bundle.main.bundleIdentifier!)
    }

    static var sceneMetadata: URL {
        applicationSupportDirectory.appendingPathComponent("scenes.json")
    }
}
