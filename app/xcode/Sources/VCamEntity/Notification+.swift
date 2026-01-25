//
//  Notification+.swift
//
//
//  Created by Tatsuya Tanaka on 2022/04/12.
//

import Foundation

public extension Notification.Name {
    static let showEmojiPicker = Notification.Name("vcam.showEmojiPicker")
    static let deviceWasChanged = Notification.Name("vcam.deviceWasChanged")
    static let unfocusObject = Notification.Name("vcam.unfocusObject")
    static let aspectRatioDidChange = Notification.Name("vcam.aspectRatioDidChange")
}
