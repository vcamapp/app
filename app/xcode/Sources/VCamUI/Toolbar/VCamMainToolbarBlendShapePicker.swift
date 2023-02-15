//
//  VCamMainToolbarBlendShapePicker.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/02/12.
//

import SwiftUI

public struct VCamMainToolbarBlendShapePicker: View {
    public init(blendShapes: [String], selectedBlendShape: Binding<String?>) {
        self.blendShapes = blendShapes
        self._selectedBlendShape = selectedBlendShape
    }

    let blendShapes: [String]
    @Binding var selectedBlendShape: String?

    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            GroupBox {
                LazyVGrid(columns: Array(repeating: GridItem(.adaptive(minimum: 80), spacing: 2), count: 3)) {
                    ForEach(blendShapes, id: \.self) { blendShape in
                        HoverToggle(text: blendShape, isOn: $selectedBlendShape.map(
                            get: { blendShape == $0 },
                            set: { $0 ? blendShape : nil }
                        ))
                    }
                }
            }
        }
        .frame(width: 280, height: 150)
    }

    struct HoverToggle: View {
        let text: String
        @Binding var isOn: Bool

        var body: some View {
            Button(action: { isOn.toggle() }) {
                Text(text)
                    .font(.callout)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .macHoverEffect()
                    .background(isOn ? Color.accentColor.opacity(0.3) : nil)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
    }
}

struct VCamMainToolbarBlendShapePicker_Previews: PreviewProvider {
    static var previews: some View {
        VCamMainToolbarBlendShapePicker(blendShapes: ["natural", "joy"], selectedBlendShape: .constant("joy"))
    }
}
