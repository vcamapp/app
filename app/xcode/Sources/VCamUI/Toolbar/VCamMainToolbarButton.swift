//
//  VCamMainToolbarButton.swift
//
//
//  Created by tattn on 2025/12/13.
//

import SwiftUI

struct VCamMainToolbarButton: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder var label: () -> Text

    var body: some View {
        Button(action: action) {
            label()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .macHoverEffect()
                .background(isSelected ? Color.accentColor.opacity(0.3) : nil)
                .cornerRadiusConcentric(4)
        }
        .buttonStyle(.plain)
    }
}
