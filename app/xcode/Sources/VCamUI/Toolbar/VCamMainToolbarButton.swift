import SwiftUI

struct VCamMainToolbarButton: View {
    let isSelected: Bool
    let action: () -> Void
    let label: Text

    var body: some View {
        Button(action: action) {
            label
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .macHoverEffect()
                .background(isSelected ? Color.accentColor.opacity(0.3) : nil)
                .cornerRadiusConcentric(4)
        }
        .buttonStyle(.plain)
    }
}
