import Foundation
import SwiftUI
import VCamData

public struct VCamContentView: View {
    public init() {}
    
    @Environment(VCamUIState.self) var state

    public var body: some View {
        content()
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(.thinMaterial)
    }

    @ViewBuilder
    func content() -> some View {
        switch state.currentMenu {
        case .main:
            VCamMainView()
#if FEATURE_3
        case .screenEffect:
            if UniState.shared.value(for: .useURP) {
                VCamScreenEffectURPView()
            } else {
                VCamDisplayView()
            }
#endif
        case .recording:
            VCamRecordingView()
        }
    }
}

#Preview {
    VCamContentView()
        .frame(width: 500, height: 300)
        .background(Color.white)
}
