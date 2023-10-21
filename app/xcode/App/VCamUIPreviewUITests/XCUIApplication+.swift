//
//  XCUIApplication+.swift
//  VCamUIPreviewUITests
//
//  Created by Tatsuya Tanaka on 2023/10/22.
//

import XCTest
import VCamData
import VCamDefaults

extension XCUIApplication {
    struct Configuration {
        static let `default` = Configuration()
        var previousVersion: String? = "999.9.9" // skip migration
    }

    static func make(with configuration: Configuration = .default) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["UITesting"]
        if let value = configuration.previousVersion {
            app.setUserDefaults(value: value, for: .previousVersion)
        }
        return app
    }

    func setUserDefaults<T: UserDefaultsValue>(value: String, for key: UserDefaults.Key<T>) {
        launchArguments += ["-\(key.rawValue)", value]
    }
}
