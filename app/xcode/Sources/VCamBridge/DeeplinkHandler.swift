//
//  DeeplinkHandler.swift
//
//
//  Created by tattn on 2025/11/15.
//

import Foundation

@_cdecl("uniHandleDeepLink")
public func uniHandleDeepLink(_ url: UnsafePointer<CChar>) {
    let urlString = String(cString: url)
    DeeplinkHandler.handleURL(URL(string: urlString)!)
}

public enum DeeplinkHandler {
    public static var handleURL: (URL) -> Void = { _ in }
}
