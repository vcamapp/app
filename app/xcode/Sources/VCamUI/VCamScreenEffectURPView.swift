import SwiftUI

public struct VCamScreenEffectURPView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            Text(.screenEffectURPInDevelopment)
                .font(.headline)
            Text(.screenEffectURPHowToUse)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    VCamScreenEffectURPView()
        .frame(width: 500, height: 300)
}
