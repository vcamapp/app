//
//  LaunchScreenshotTests.swift
//  VCamUIPreviewUITests
//
//  Created by Tatsuya Tanaka on 2023/10/18.
//

import XCTest
import VCamLocalization

final class LaunchScreenshotTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        LocalizationEnvironment.currentLocale = { "en_US" }
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Close the alert about the virtual camera if needed"
        if app.staticTexts[L10n.installVirtualCamera.text].exists {
            app.buttons["OK"].click()
            app.buttons["OK"].click()
        }

        XCTContext.runActivity(named: "Launch Screen") { activity in
            add(.keepAlways(screenshot: app.screenshot(), activity: activity))
        }

        XCTContext.runActivity(named: "\(L10n.recording.text) Screen") { activity in
            app.buttons[L10n.recording.text].click()
            _ = app.staticTexts[L10n.whiteBalance.text].waitForExistence(timeout: 5)
            add(.keepAlways(screenshot: app.screenshot(), activity: activity))
        }

        XCTContext.runActivity(named: "\(L10n.screenEffect.text) Screen") { activity in
            app.buttons[L10n.screenEffect.text].click()
            _ = app.staticTexts[L10n.startRecording.text].waitForExistence(timeout: 5)
            add(.keepAlways(screenshot: app.screenshot(), activity: activity))
        }
    }
}

private extension XCTAttachment {
    static func keepAlways(screenshot: XCUIScreenshot, activity: XCTActivity) -> XCTAttachment {
        let attachment = XCTAttachment(screenshot: screenshot, quality: .low)
        attachment.name = activity.name
        attachment.lifetime = .keepAlways
        return attachment
    }
}
