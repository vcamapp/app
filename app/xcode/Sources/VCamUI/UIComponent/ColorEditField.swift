import SwiftUI

public struct ColorEditField: View {
    public init(_ label: LocalizedStringResource, value: Binding<Color>) {
        self.label = label
        self._value = value
    }

    let label: LocalizedStringResource
    @Binding var value: Color

    public var body: some View {
        ColorPicker(selection: $value) {
            Text(label).bold()
                .lineLimit(1)
                .modifier { view in
                    if #available(macOS 26.0, *) {
                        view.offset(x: 0, y: -8)
                    } else {
                        view
                    }
                }
        }
    }
}

extension ColorEditField: @MainActor Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.value == rhs.value && lhs.label == rhs.label
    }
}


#Preview {
    @Previewable @State var color: Color = .red
    ColorEditField("Preview Color", value: $color)
}
