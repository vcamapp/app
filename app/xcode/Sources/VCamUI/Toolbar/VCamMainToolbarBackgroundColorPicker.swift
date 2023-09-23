//
//  VCamMainToolbarBackgroundColorPicker.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/02/12.
//

import SwiftUI
import VCamUIFoundation

public struct VCamMainToolbarBackgroundColorPicker: View {
    public init(backgroundColor: Binding<Color>) {
        self._backgroundColor = backgroundColor
    }

    @Binding var backgroundColor: Color

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

struct VCamMainToolbarPhotoPicker_Previews: PreviewProvider {
    static var previews: some View {
        VCamMainToolbarBackgroundColorPicker(backgroundColor: .constant(.red))
    }
}
