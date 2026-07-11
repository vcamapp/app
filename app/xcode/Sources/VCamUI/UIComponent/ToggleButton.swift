import SwiftUI
import Combine

public struct ToggleButton: View {
    public init(_ title: LocalizedStringResource, isOn: Binding<Bool>) {
        self.text = Text(title)
        self._isOn = isOn
    }

    public init(_ title: String, isOn: Binding<Bool>) {
        self.text = Text(title)
        self._isOn = isOn
    }

    let text: Text
    @Binding private var isOn: Bool

    public var body: some View {
        Toggle(isOn: $isOn) {
            text
        }
        .toggleStyle(.button)
    }
}
