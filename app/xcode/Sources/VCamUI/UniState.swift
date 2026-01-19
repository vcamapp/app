//
//  UniState.swift
//
//
//  Created by tattn on 2025/12/07.
//

import Foundation
import VCamEntity
#if DEBUG
import VCamBridge
#endif

@Observable
public final class UniState {
    public static let shared = UniState()

    public init() {}

#if DEBUG
    public static func preview(
        motions: [Avatar.Motion] = [],
        isMotionPlaying: [Avatar.Motion: Bool] = [:],
        expressions: [Avatar.Expression] = [],
        currentExpressionIndex: Int? = nil,
        blendShapeNames: [String] = TrackingMappingEntry.defaultMappings(for: .blendShape).map(\.input.key)
    ) -> UniState {
        let state = UniState()
        state.motions = motions
        state.isMotionPlaying = isMotionPlaying
        state.expressions = expressions
        state.currentExpressionIndex = currentExpressionIndex
        state.blendShapeNames = blendShapeNames
        return state
    }
#endif

    public fileprivate(set) var motions: [Avatar.Motion] = []
    public fileprivate(set) var isMotionPlaying: [Avatar.Motion: Bool] = [:]
    public fileprivate(set) var expressions: [Avatar.Expression] = []
    public fileprivate(set) var currentExpressionIndex: Int?
    public fileprivate(set) var blendShapeNames: [String] = []
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

@_cdecl("uniStateSetBlendShapeNames")
public func uniStateSetBlendShapeNames(_ namesPtr: UnsafePointer<UnsafePointer<CChar>?>, _ count: Int32) {
    let names: [String] = (0..<Int(count)).compactMap { index in
        guard let cString = namesPtr.advanced(by: index).pointee else { return nil }
        return String(cString: cString)
    }
    UniState.shared.blendShapeNames = names
}
