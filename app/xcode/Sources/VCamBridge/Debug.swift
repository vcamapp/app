//
//  Debug.swift
//
//
//  Created by Tatsuya Tanaka on 2022/05/09.
//
//
import AppKit
import SwiftUI

private var debugLog: ((String) -> Void)?


@_cdecl("uniRegisterDebugLog")
public func uniRegisterDebugLog(_ function: @escaping @convention(c) (UnsafePointer<CChar>) -> Void) {
    debugLog = { function(($0 as NSString).utf8String!) }
}

public func uniDebugLog(_ message: String) {
    guard Thread.isMainThread else {
        DispatchQueue.main.async {
            uniDebugLog(message)
        }
        return
    }

    debugLog?(message)
}
