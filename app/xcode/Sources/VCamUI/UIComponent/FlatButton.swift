import SwiftUI

public struct FlatButton<LabelItem: View>: View {
    public init(action: @escaping () -> Void, doubleTapAction: (() -> Void)? = nil, @ViewBuilder label: () -> LabelItem) {
        self.action = action
        self.doubleTapAction = doubleTapAction
        self.label = label()
    }

    let action: () -> Void
    let doubleTapAction: (() -> Void)?
    let label: LabelItem

    @Environment(\.flatButtonStyle) var flatButtonStyle

    public var body: some View {
        container {
            label
        }
        .background(flatButtonStyle.backgroundColor)
        .cornerRadius(flatButtonStyle.cornerRadius)
        .macHoverEffect(padding: 0)
        .modifier(TapGestureModifier(action: action, doubleTapAction: doubleTapAction))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            action()
        }
    }

    @ViewBuilder func container(content: () -> some View) -> some View {
        if flatButtonStyle.hasBorder {
            GroupBox {
                content()
                    .padding(2)
            }
        } else {
            content()
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
        }
    }
}

// exclusively(before:) delays single taps by the double-tap window,
// so attach it only when a double-tap action actually exists
private struct TapGestureModifier: ViewModifier {
    let action: () -> Void
    let doubleTapAction: (() -> Void)?

    func body(content: Content) -> some View {
        if let doubleTapAction {
            content.gesture(
                TapGesture(count: 2)
                    .exclusively(before: TapGesture())
                    .onEnded { value in
                        switch value {
                        case .first: doubleTapAction()
                        case .second: action()
                        }
                    }
            )
        } else {
            content.onTapGesture(perform: action)
        }
    }
}

public extension View {
    func flatButtonStyle(_ style: FlatButtonStyle) -> some View {
        environment(\.flatButtonStyle, style)
    }
}

public struct FlatButtonStyle: Sendable {
    public var hasBorder = true
    public var backgroundColor: Color?
    public var cornerRadius: CGFloat = 0

    public static let label = FlatButtonStyle(
        hasBorder: false
    )

    public static func filled(color: Color? = nil) -> FlatButtonStyle {
        FlatButtonStyle(
            hasBorder: false,
            backgroundColor: color ?? .white.opacity(0.05),
            cornerRadius: 4
        )
    }
}

public extension EnvironmentValues {
    @Entry var flatButtonStyle = FlatButtonStyle()
}

#Preview {
    FlatButton {
    } label: {
        Text(verbatim: "Hello")
    }
    .padding()
}

#Preview("filled") {
    FlatButton {
    } label: {
        Text(verbatim: "Hello")
    }
    .flatButtonStyle(.filled())
    .padding()
}
