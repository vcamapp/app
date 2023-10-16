//
//  VCamMainToolbarBackgroundColorPicker.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/02/12.
//

import SwiftUI
import VCamUIFoundation
import VCamBridge

public struct VCamMainToolbarBackgroundColorPicker: View {
    public init(
        backgroundColor: ExternalStateBinding<Color> = .init(.backgroundColor)
    ) {
        _backgroundColor = backgroundColor
    }

    @ExternalStateBinding(.backgroundColor) private var backgroundColor: Color

    public var body: some View {
        GroupBox {
            Form {
                HStack {
                    Text(L10n.color.key, bundle: .localize)
                        .fixedSize(horizontal: true, vertical: false)
                    ColorEditField(L10n.color.key, value: $backgroundColor)
                        .labelsHidden()
                }
            }
        }
    }
}

#Preview {
    VCamMainToolbarBackgroundColorPicker(backgroundColor: .constant(.red))
}
