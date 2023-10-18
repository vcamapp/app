//
//  VCamUIPreviewUITestsLaunchTests.swift
//  VCamUIPreviewUITests
//
//  Created by Tatsuya Tanaka on 2023/10/18.
//

import XCTest

final class VCamUIPreviewUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
