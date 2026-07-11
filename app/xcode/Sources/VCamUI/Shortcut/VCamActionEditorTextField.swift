import SwiftUI

struct VCamActionEditorTextField: View {
    @Binding var value: String

    var body: some View {
        TextField(text: $value) { EmptyView() }
            .textFieldStyle(.roundedBorder)
    }
}

struct VCamActionEditorTextField_Previews: PreviewProvider {
    static var previews: some View {
        VCamActionEditorTextField(value: .constant("hello"))
    }
}
