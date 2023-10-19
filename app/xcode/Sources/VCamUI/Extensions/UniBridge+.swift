//
//  UniBridge+.swift
//
//
//  Created by Tatsuya Tanaka on 2022/05/23.
//

import Foundation
import VCamEntity
import SwiftUI
import VCamBridge

extension UniState {
    public init(_ state: CustomState) {
        get = state.get
        set = state.set
        name = state.name
        reloadThrottle = state.reloadThrottle
    }

    public struct CustomState {
        public init(get: @escaping () -> Value, set: @escaping (Value) -> Void, name: String = "", reloadThrottle: Bool = false) {
            self.get = get
            self.set = set
            self.name = name
            self.reloadThrottle = reloadThrottle
        }

        public var get: () -> Value
        public var set: (Value) -> Void
        public var name = ""
        public var reloadThrottle = false
    }
}

extension UniBridge {
    public var canvasCGSize: CGSize {
        let size = canvasSize
        guard size.count == 2 else { return .init(width: 1920, height: 1280) } // an empty array after disposal
        return .init(width: CGFloat(size[0]), height: CGFloat(size[1]))
    }

    public static var cachedBlendShapes: [String] = []
    public var cachedBlendShapes: [String] {
        Self.cachedBlendShapes
    }
}
