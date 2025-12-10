//
//  UniState.swift
//
//
//  Created by tattn on 2025/12/07.
//

import Foundation
import VCamEntity

@Observable
public final class UniState {
    public static let shared = UniState()

    public init() {}

#if DEBUG
    public init(
        isMotionPlaying: [Motion: Bool]
    ) {
        self.isMotionPlaying = isMotionPlaying
    }
#endif

    public fileprivate(set) var isMotionPlaying: [Motion: Bool] = [:]
}

@_cdecl("uniStateSetMotionPlaying")
public func uniStateSetMotionPlaying(_ motion: UnsafePointer<CChar>, _ isPlaying: Bool) {
    let motion = Motion(name: String(cString: motion))
    UniState.shared.isMotionPlaying[motion] = isPlaying
}
