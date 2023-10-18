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
        LocalizationEnvironment.currentLocale = { "en_US" }
    }

    override func tearDownWithError() throws {
    }

    func testLaunchApp() throws {
        let app = XCUIApplication()
        app.launch()

        XCTContext.runActivity(named: "Close the alert about the virtual camera if needed") { _ in
            if app.staticTexts[L10n.installVirtualCamera.text].exists {
                app.buttons["OK"].click()
                app.buttons["OK"].click()
            }
        }

        XCTContext.runActivity(named: "Check VCamUI") { _ in
            XCTAssertTrue(app.buttons[L10n.main.text].exists)
        }
    }
}
