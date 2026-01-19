//
//  VCamMainToolbarBlendShapePicker.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/02/12.
//

import SwiftUI
import VCamBridge
import VCamEntity

public struct VCamMainToolbarExpressionPicker: View {
    public init() {}

    @Environment(UniState.self) var uniState

    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            GroupBox {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))]) {
                    ForEach(Array(uniState.expressions.enumerated()), id: \.element.name) { (index, expression) in
                        VCamMainToolbarButton(
                            isSelected: uniState.currentExpressionIndex == index) {
                                UniBridge.applyExpression(name: expression.name)
                            } label: {
                                Text(.init(expression.name), bundle: .localize)
                            }
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
}

extension VCamMainToolbarExpressionPicker: MacWindow {
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

#if DEBUG

#Preview {
    VCamMainToolbarExpressionPicker()
        .frame(minWidth: 200)
        .environment(UniState.preview(
            expressions: [
                .init(name: "A"),
                .init(name: "I"),
                .init(name: "U"),
                .init(name: "E"),
                .init(name: "O"),
                .init(name: "Angry"),
                .init(name: "Fun"),
                .init(name: "Joy"),
                .init(name: "Sorrow"),
                .init(name: "Surprised"),
                .init(name: "AAAAAAAA"),
                .init(name: "BBBBBBBB"),
                .init(name: "CCCCCC"),
                .init(name: "DDDDDD"),
                .init(name: "EEEE"),
                .init(name: "FFFFFFF"),
                .init(name: "GGGGGGG"),
            ],
            currentExpressionIndex: 0
        ))
}

#endif
