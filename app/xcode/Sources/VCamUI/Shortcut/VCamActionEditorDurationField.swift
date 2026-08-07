import SwiftUI

struct VCamActionEditorDurationField: View {
    @Binding var value: Double

    var body: some View {
        HStack(spacing: 4) {
            TextField(value: $value, format: .number) { EmptyView() }
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
            Text(.seconds)
        }
        .frame(width: 80)
    }
}

#Preview {
    VCamActionEditorDurationField(value: .constant(100))
}
