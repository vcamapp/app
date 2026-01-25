//
//  LaunchScreenshotTests.swift
//  VCamUIPreviewUITests
//
//  Created by Tatsuya Tanaka on 2023/10/18.
//

import XCTest
import VCamLocalization
import VCamUI

final class LaunchScreenshotTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false // Light mode only
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        LocalizationEnvironment.currentLocaleIdentifier = { "en_US" }
    }

    func testLaunch() throws {
        let app = XCUIApplication.make()
        app.launch()

        XCTContext.runActivity(named: "Launch Screen") { activity in
            add(.keepAlways(screenshot: app.screenshot(), activity: activity))
        }

        XCTContext.runActivity(named: "\(L10n.screenEffect.text) Screen") { activity in
            app.buttons.contains(label: L10n.screenEffect.text).click()
            _ = app.staticTexts[L10n.startRecording.text].waitForExistence(timeout: 5)
            add(.keepAlways(screenshot: app.screenshot(), activity: activity))
        }

        XCTContext.runActivity(named: "\(L10n.recording.text) Screen") { activity in
            app.buttons.contains(label: L10n.recording.text).click()
            _ = app.staticTexts[L10n.whiteBalance.text].waitForExistence(timeout: 5)
            add(.keepAlways(screenshot: app.screenshot(), activity: activity))
        }

        XCTContext.runActivity(named: "\(L10n.settings.text) Screen") { activity in
            app.buttons["btn_settings"].click()
            _ = app.staticTexts[L10n.settings.text].waitForExistence(timeout: 5)
            add(.keepAlways(screenshot: app.screenshot(), activity: activity))
            XCTAssertTrue(app.cells.firstMatch.isSelected)

            XCTContext.runActivity(named: "\(activity.name) - \(L10n.rendering.text)") { activity in
                app.cells.staticTexts[L10n.rendering.text].click()
                _ = app.staticTexts[L10n.renderingQuality.text].waitForExistence(timeout: 5)
                add(.keepAlways(screenshot: app.screenshot(), activity: activity))
            }

            XCTContext.runActivity(named: "\(activity.name) - \(L10n.tracking.text)") { activity in
                app.cells.staticTexts[L10n.tracking.text].click()
                _ = app.staticTexts[L10n.fpsCamera.text].waitForExistence(timeout: 5)
                add(.keepAlways(screenshot: app.screenshot(), activity: activity))
            }

            XCTContext.runActivity(named: "\(activity.name) - \(L10n.virtualCamera.text)") { activity in
                app.cells.staticTexts[L10n.virtualCamera.text].click()
                _ = app.staticTexts[L10n.noteEnableNewCameraExtension.text].waitForExistence(timeout: 5)
                add(.keepAlways(screenshot: app.screenshot(), activity: activity))
            }

            XCTContext.runActivity(named: "\(activity.name) - \(L10n.integration.text)") { activity in
                app.cells.staticTexts[L10n.integration.text].click()
                _ = app.staticTexts["VCamMocap"].waitForExistence(timeout: 5)
                add(.keepAlways(screenshot: app.screenshot(), activity: activity))
            }

            XCTContext.runActivity(named: "\(activity.name) - \(L10n.experiment.text)") { activity in
                app.cells.staticTexts[L10n.experiment.text].click()
                add(.keepAlways(screenshot: app.screenshot(), activity: activity))
            }
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
