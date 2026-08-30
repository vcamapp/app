import SwiftUI
import VCamControl
import VCamEntity
import VCamData

public struct VCamMainToolbarExpressionPicker: View {
    public init() {}

    @Environment(UniState.self) var uniState

    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            GroupBox {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))]) {
                    ForEach(uniState.expressions) { expression in
                        VCamMainToolbarButton(
                            isSelected: expression.name == uniState.currentExpressionName,
                            action: {
                                ExpressionControl.apply(name: expression.name)
                            },
                            label: Text(expression.name)
                        )
                    }
                }
            }
        }
        .floatingTransparentPanelContent()
    }
}

extension VCamMainToolbarExpressionPicker: MacWindow {
    public var windowTitle: String {
        String(localized: .facialExpression)
    }

    public func configureWindow(_ window: NSWindow) -> NSWindow {
        configureAsFloatingTransparentPanel(window, contentSize: .init(width: 200, height: 200))
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
            currentExpressionName: "Angry"
        ))
}

#endif
