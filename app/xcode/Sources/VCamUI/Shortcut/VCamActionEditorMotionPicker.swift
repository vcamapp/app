import SwiftUI
import VCamEntity
import VCamData

struct VCamActionEditorMotionPicker: View {
    @Binding var motionID: String

    var body: some View {
        VCamActionEditorPicker(item: $motionID, items: candidates, mapValue: \.id, displayName: \.localizedDisplayName)
    }

    private var candidates: [Avatar.Motion] {
        var motions = MotionLibrary.shared.allMotions
        if !motions.contains(where: { $0.id == motionID }) {
            motions.append(.init(id: motionID, displayName: String(localized: .deletedMotion)))
        }
        return motions
    }
}
