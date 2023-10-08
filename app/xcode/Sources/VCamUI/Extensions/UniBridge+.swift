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

extension UniState<ScreenResolution>.CustomState {
    public static var typedScreenResolution: Self {
        let rawValue = UniState<[Int32]>(.screenResolution, name: "screenResolution", as: [Int32].self)
        return .init {
            let size = rawValue.wrappedValue
            guard size.count == 2 else { return .init(width: 1920, height: 1280) } // an empty array after disposal
            return ScreenResolution(width: Int(size[0]), height: Int(size[1]))
        } set: {
            let isLandscape = MainTexture.shared.isLandscape
            rawValue.wrappedValue = [Int32($0.size.width), Int32($0.size.height)]
            if isLandscape != MainTexture.shared.isLandscape {
                SceneManager.shared.changeAspectRatio()
            }
        }
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
