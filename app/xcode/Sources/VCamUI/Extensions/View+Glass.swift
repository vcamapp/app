//
//  View+Glass.swift
//
//
//  Created by tattn on 2025/12/18.
//

import SwiftUI

public extension View {
    @ViewBuilder
    func cornerRadiusConcentric(_ radius: CGFloat) -> some View {
        if #available(macOS 26, *) {
            clipShape(.rect(corners: .concentric(minimum: .fixed(radius)), isUniform: true))
        } else {
            clipShape(.rect(cornerRadius: radius))
        }
    }
}
