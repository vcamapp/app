import XCTest
import VCamUI

final class LaunchScreenshotTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false // Light mode only
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication.make()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        XCTContext.runActivity(named: "Launch Screen") { activity in
            add(.keepAlways(screenshot: app.screenshot(), activity: activity))
        }

        XCTContext.runActivity(named: "Screen Effect Screen") { activity in
            app.buttons["menu.screenEffect"].click()
            _ = app.buttons["recording.startButton"].waitForExistence(timeout: 5)
            add(.keepAlways(screenshot: app.screenshot(), activity: activity))
        }

        XCTContext.runActivity(named: "Recording Screen") { activity in
            app.buttons["menu.recording"].click()
            _ = app.descendants(matching: .any)["display.whiteBalance"].waitForExistence(timeout: 5)
            add(.keepAlways(screenshot: app.screenshot(), activity: activity))
        }

        XCTContext.runActivity(named: "Settings Screen") { activity in
            app.buttons["btn_settings"].click()
            _ = app.buttons["settings.tab.general"].waitForExistence(timeout: 5)
            add(.keepAlways(screenshot: app.screenshot(), activity: activity))
            XCTAssertTrue(app.cells.firstMatch.isSelected)

            XCTContext.runActivity(named: "\(activity.name) - Rendering") { activity in
                app.cells["settings.tab.rendering"].click()
                _ = app.descendants(matching: .any)["settings.rendering.quality"].waitForExistence(timeout: 5)
                add(.keepAlways(screenshot: app.screenshot(), activity: activity))
            }

            XCTContext.runActivity(named: "\(activity.name) - Tracking") { activity in
                app.cells["settings.tab.tracking"].click()
                add(.keepAlways(screenshot: app.screenshot(), activity: activity))
            }

            XCTContext.runActivity(named: "\(activity.name) - Virtual Camera") { activity in
                app.cells["settings.tab.virtualCamera"].click()
                add(.keepAlways(screenshot: app.screenshot(), activity: activity))
            }

            XCTContext.runActivity(named: "\(activity.name) - Integration") { activity in
                app.cells["settings.tab.integration"].click()
                _ = app.staticTexts["VCamMocap"].waitForExistence(timeout: 5)
                add(.keepAlways(screenshot: app.screenshot(), activity: activity))
            }

            XCTContext.runActivity(named: "\(activity.name) - Experiment") { activity in
                app.cells["settings.tab.experiment"].click()
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
