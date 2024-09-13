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

extension UniBridge {
    public var canvasCGSize: CGSize {
        let size = canvasSize
        guard size.count == 2 else { return .init(width: 1920, height: 1280) } // an empty array after disposal
        return .init(width: CGFloat(size[0]), height: CGFloat(size[1]))
    }

    public static var cachedBlendShapes: [BlendShape] = []
    public var cachedBlendShapes: [BlendShape] {
        Self.cachedBlendShapes
    }
}
