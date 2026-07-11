import SwiftUI
import VCamUIFoundation
import VCamData

public struct VCamMainToolbarBackgroundColorPicker: View {
    public init() {}

    @Environment(UniState.self) private var uniState

    public var body: some View {
        @Bindable var state = uniState

        GroupBox {
            Form {
                HStack {
                    Text(.color)
                        .fixedSize(horizontal: true, vertical: false)
                    ColorEditField(.color, value: $state.backgroundColor)
                        .labelsHidden()
                }
            }
        }
    }
}

#if DEBUG

#Preview {
    VCamMainToolbarBackgroundColorPicker()
        .environment(UniState.preview(backgroundColor: .red))
}

#endif
