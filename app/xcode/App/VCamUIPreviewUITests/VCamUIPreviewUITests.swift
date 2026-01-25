//
//  VCamUIPreviewUITests.swift
//  VCamUIPreviewUITests
//
//  Created by Tatsuya Tanaka on 2023/10/18.
//

import XCTest
import VCamLocalization

final class VCamUIPreviewUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        LocalizationEnvironment.currentLocaleIdentifier = { "en_US" }
    }

    override func tearDownWithError() throws {
    }

    func testLaunchApp() throws {
        let app = XCUIApplication.make()
        app.launch()

        XCTContext.runActivity(named: "Check VCamUI") { _ in
            XCTAssertTrue(app.buttons.contains(label: L10n.main.text).exists)
        }
    }
}
