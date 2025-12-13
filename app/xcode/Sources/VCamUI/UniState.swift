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
        motions: [Avatar.Motion] = [],
        isMotionPlaying: [Avatar.Motion: Bool] = [:],
        expressions: [Avatar.Expression] = [],
        currentExpressionIndex: Int? = nil
    ) {
        self.isMotionPlaying = isMotionPlaying
        self.expressions = expressions
        self.currentExpressionIndex = currentExpressionIndex
    }
#endif

    public fileprivate(set) var motions: [Avatar.Motion] = []
    public fileprivate(set) var isMotionPlaying: [Avatar.Motion: Bool] = [:]
    public fileprivate(set) var expressions: [Avatar.Expression] = []
    public fileprivate(set) var currentExpressionIndex: Int?
}

@_cdecl("uniStateSetMotions")
public func uniStateSetMotions(_ motionsPtr: UnsafePointer<UnsafePointer<CChar>?>, _ count: Int32) {
    let motions: [Avatar.Motion] = (0..<Int(count)).compactMap { index in
        guard let cString = motionsPtr.advanced(by: index).pointee else { return nil }
        return Avatar.Motion(name: String(cString: cString))
    }
    UniState.shared.motions = motions
}

@_cdecl("uniStateSetMotionPlaying")
public func uniStateSetMotionPlaying(_ motion: UnsafePointer<CChar>, _ isPlaying: Bool) {
    let motion = Avatar.Motion(name: String(cString: motion))
    UniState.shared.isMotionPlaying[motion] = isPlaying
}

@_cdecl("uniStateSetExpressions")
public func uniStateSetExpressions(_ expressionsPtr: UnsafePointer<UnsafePointer<CChar>?>, _ count: Int32) {
    let expressions: [Avatar.Expression] = (0..<Int(count)).compactMap { index in
        guard let cString = expressionsPtr.advanced(by: index).pointee else { return nil }
        return Avatar.Expression(name: String(cString: cString))
    }
    UniState.shared.expressions = expressions
    UniState.shared.currentExpressionIndex = nil
}

@_cdecl("uniStateSetCurrentExpressionIndex")
public func uniStateSetCurrentExpressionIndex(_ index: Int32) {
    UniState.shared.currentExpressionIndex = index >= 0 ? Int(index) : nil
}
