//
//  MacHoverEffect.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/02/12.
//

import SwiftUI

public struct HoverEffectButtonViewModifier: ViewModifier {
    public init(padding: CGFloat) {
        self.padding = padding
    }

    let padding: CGFloat

    @State private var isHovered = false

    @Environment(\.isEnabled) private var isEnabled

    public func body(content: Content) -> some View {
        let isHovered = isEnabled ? isHovered : false
        content
            .padding(padding)
            .background(isHovered ? Color.white.opacity(0.1) : nil)
            .cornerRadius(4)
            .onHover {
                self.isHovered = $0
            }
    }
}

public extension View {
    @inlinable
    func macHoverEffect(padding: CGFloat = 4) -> some View {
        modifier(HoverEffectButtonViewModifier(padding: padding))
    }
}
