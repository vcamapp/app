//
//  Logger.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/04/14.
//

import Foundation

public struct Logger {
    public static var error: (any Error) -> Void = { print($0) }

    public static func log(_ message: String, file: StaticString = #file, function: StaticString = #function, line: Int = #line) {
        logInternal(message, file, function, line)
    }

    public static var logInternal: (String, StaticString, StaticString, Int) -> Void = {
        print($0, $1, $2, $3)
    }
}

public extension Logger {
    enum Event: String {
        case installPlugin = "install_plugin"
        case openVRoidHub = "open_vroidhub"
        case loadVRMFile = "load_vrmfile"
    }

    static func log(event: Event) {
        logEventInternal(event)
    }

    static var logEventInternal: (Event) -> Void = {
        print($0)
    }
}
