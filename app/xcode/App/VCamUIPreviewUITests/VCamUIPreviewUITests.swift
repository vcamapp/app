import XCTest
import VCamUI

final class VCamUIPreviewUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
    }

    func testLaunchApp() throws {
        let app = XCUIApplication.make()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        XCTContext.runActivity(named: "Check VCamUI") { _ in
            XCTAssertTrue(app.buttons["menu.main"].exists)
        }
    }
}
