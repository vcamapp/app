//
//  VCamMainToolbarBackgroundColorPicker.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/02/12.
//

import SwiftUI
import VCamUIFoundation

public struct VCamMainToolbarBackgroundColorPicker: View {
    public init() {}

    @Environment(UniState.self) private var uniState

    public var body: some View {
        @Bindable var state = uniState

        GroupBox {
            Form {
                HStack {
                    Text(L10n.color.key, bundle: .localize)
                        .fixedSize(horizontal: true, vertical: false)
                    ColorEditField(L10n.color.key, value: $state.backgroundColor)
                        .labelsHidden()
                }
            }
        }
    }
}

#if DEBUG

#Preview {
    VCamMainToolbarBackgroundColorPicker()
        .environment(UniState.preview(backgroundColor: .red))
}

#endif
