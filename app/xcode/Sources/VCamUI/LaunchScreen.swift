//
//  LaunchScreen.swift
//
//
//  Created by tattn on 2025/12/27.
//

import SwiftUI

public struct LaunchScreen: View {
    public static var content: () -> AnyView = {
        AnyView(Image("AppIcon", bundle: .main).resizable().scaledToFit().frame(height: 120))
    }
    public static var duration = Duration.seconds(1.0)

    let onDismiss: () -> Void

    public var body: some View {
        Self.content()
            .task {
                try? await Task.sleep(for: Self.duration)
                onDismiss()
            }
    }
}
