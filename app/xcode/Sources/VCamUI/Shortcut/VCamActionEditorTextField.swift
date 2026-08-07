import SwiftUI

struct VCamActionEditorTextField: View {
    @Binding var value: String

    var body: some View {
        TextField(text: $value) { EmptyView() }
            .textFieldStyle(.roundedBorder)
    }
}

#Preview {
    VCamActionEditorTextField(value: .constant("hello"))
}
