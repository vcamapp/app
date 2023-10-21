//
//  XCUIElementQuery+.swift
//  VCamUIPreviewUITests
//
//  Created by Tatsuya Tanaka on 2023/10/22.
//

import XCTest

extension XCUIElementQuery {
    func contains(label: String) -> XCUIElement {
        containing(.init(format: "label CONTAINS '\(label)'")).element
    }
}
