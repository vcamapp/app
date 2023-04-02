//
//  FlatButton.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/01.
//

import SwiftUI

public struct FlatButton<LabelItem: View>: View {
    public init(action: @escaping () -> Void, doubleTapAction: @escaping () -> Void = {}, @ViewBuilder label: @escaping () -> LabelItem) {
        self.action = action
        self.doubleTapAction = doubleTapAction
        self.label = label
    }

    let action: () -> Void
    let doubleTapAction: () -> Void
    @ViewBuilder var label: () -> LabelItem

    @Environment(\.flatButtonStyle) var flatButtonStyle

    public var body: some View {
        container {
            label()
        }
        .background(flatButtonStyle.backgroundColor)
        .cornerRadius(flatButtonStyle.cornerRadius)
        .macHoverEffect(padding: 0)
        .gesture(TapGesture(count: 2).onEnded {
            doubleTapAction()
        })
        .simultaneousGesture(TapGesture().onEnded {
            action()
        })
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

public extension View {
    func flatButtonStyle(_ style: FlatButtonStyle) -> some View {
        environment(\.flatButtonStyle, style)
    }
}

public struct FlatButtonStyle {
    public var hasBorder = true
    public var backgroundColor: Color?
    public var cornerRadius: CGFloat = 0

    public static let label = FlatButtonStyle(
        hasBorder: false
    )

    public static let filled = FlatButtonStyle(
        hasBorder: false,
        backgroundColor: .white.opacity(0.05),
        cornerRadius: 4
    )
}

private struct FlatButtonStyleKey: EnvironmentKey {
    static let defaultValue = FlatButtonStyle()
}

public extension EnvironmentValues {
    var flatButtonStyle: FlatButtonStyle {
        get { self[FlatButtonStyleKey.self] }
        set { self[FlatButtonStyleKey.self] = newValue }
    }
}

struct FlatButton_Previews: PreviewProvider {
    static var previews: some View {
        FlatButton {
        } label: {
            Text("Hello")
        }
        .padding()

        FlatButton {
        } label: {
            Text("Hello")
        }
        .flatButtonStyle(.filled)
        .padding()
        .previewDisplayName("filled")
    }
}
