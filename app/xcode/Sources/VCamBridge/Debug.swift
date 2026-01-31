import AppKit
import SwiftUI

@MainActor private var debugLog: ((String) -> Void)?


@_cdecl("uniRegisterDebugLog")
@MainActor public func uniRegisterDebugLog(_ function: @escaping @convention(c) (UnsafePointer<CChar>) -> Void) {
    debugLog = { function(($0 as NSString).utf8String!) }
}

public func uniDebugLog(_ message: String) {
    guard Thread.isMainThread else {
        Task { @MainActor in
            uniDebugLog(message)
        }
        return
    }

    MainActor.assumeIsolated {
        debugLog?(message)
    }
}
