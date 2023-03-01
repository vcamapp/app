//
//  VCamMainToolbarBlendShapePicker.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/02/12.
//

import SwiftUI

public struct VCamMainToolbarBlendShapePicker: View {
    public init(blendShapes: [String], selectedBlendShape: () -> Binding<String?>) {
        self.blendShapes = blendShapes
        self._selectedBlendShape = selectedBlendShape()
    }

    let blendShapes: [String]
    @Binding var selectedBlendShape: String?
    @UniReload private var reload: Void

    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            GroupBox {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))]) {
                    ForEach(blendShapes, id: \.self) { blendShape in
                        HoverToggle(text: blendShape, isOn: $selectedBlendShape.map(
                            get: { blendShape == $0 },
                            set: { $0 ? blendShape : nil }
                        ))
                    }
                }
            }
        }
        .modifierOnMacWindow { content, _ in
            content
                .padding(.top, 1) // prevent from entering under the title bar.
                .padding([.leading, .trailing, .bottom], 8)
                .frame(minWidth: 200, maxWidth: .infinity, minHeight: 80, maxHeight: .infinity)
                .background(.regularMaterial)
        }
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

extension VCamMainToolbarBlendShapePicker: MacWindow {
    public var windowTitle: String {
        L10n.facialExpression.text
    }

    public func configureWindow(_ window: NSWindow) -> NSWindow {
        window.level = .floating
        window.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        window.setContentSize(.init(width: 200, height: 200))
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        return window
    }
}

struct VCamMainToolbarBlendShapePicker_Previews: PreviewProvider {
    static var previews: some View {
        VCamMainToolbarBlendShapePicker(blendShapes: ["natural", "joy"], selectedBlendShape: { .constant("joy") })
    }
}
