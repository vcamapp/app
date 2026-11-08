import SwiftUI
import VCamEntity
import VCamTracking

struct LipSyncPicker: View {
    @Bindable private var tracking = Tracking.shared

    var body: some View {
        Picker(selection: Binding(
            get: { tracking.activeLipSyncType },
            set: { tracking.lipSyncType = $0 }
        )) {
            ForEach(LipSyncType.allCases) { type in
                Text(type.name(faceTrackingMethod: tracking.faceTrackingMethod)).tag(type)
            }
        } label: {
            Text(.lipSync)
            if tracking.micLipSyncDisabled {
                Text(.lipSyncLockedDescription)
            }
        }
        .disabled(tracking.micLipSyncDisabled)
    }
}

#Preview {
    Form {
        LipSyncPicker()
    }
    .formStyle(.grouped)
}
