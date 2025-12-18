//
//  View+rootView.swift
//
//
//  Created by tattn on 2025/11/20.
//

import SwiftUI

public struct RootViewInjectionModifier: ViewModifier {
    public static var inject: (AnyView) -> AnyView = { $0 }

    public func body(content: Content) -> some View {
        Self.inject(AnyView(content))
    }
}

extension View {
    public func rootView(
        state: VCamUIState = .shared,
        uniState: UniState = .shared
    ) -> some View {
        modifier(RootViewInjectionModifier())
            .environment(state)
            .environment(uniState)
    }
}
