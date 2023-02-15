//
//  MacHoverEffect.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/02/12.
//

import SwiftUI

public struct HoverEffectButtonViewModifier: ViewModifier {
    public init() {}

    @State var isHovered = false

    public func body(content: Content) -> some View {
        content
            .padding(4)
            .background(isHovered ? Color.white.opacity(0.1) : nil)
            .cornerRadius(4)
            .onHover {
                self.isHovered = $0
            }
    }
}

public extension View {
    @inlinable
    func macHoverEffect() -> some View {
        modifier(HoverEffectButtonViewModifier())
    }
}
