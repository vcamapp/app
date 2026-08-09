import AppKit
import SwiftUI
import VCamBridge
import VCamData
import VCamTracking
import VCamUI

public enum VCamUIPreviewStub {
    @MainActor
    public static func stub() {
        MainTexture.shared.setTexture(MTLTextureStub.makeMainTexture())

        let unityView = NSView()
        unityView.wantsLayer = true
        unityView.layer?.backgroundColor = NSColor.red.cgColor
        NSApp.windows.first?.contentView = unityView

        UniBridgeStub.shared.stub(.shared)

        // Stands in for the model load that fills these from Unity
        UniState.shared.initializeFromUnity()
        UniState.shared.blendShapeNames = stubBlendShapeNames
        Tracking.shared.mappings.perfectSync = TrackingMappingEntry.defaultMappings(for: .perfectSync)

        // The app provides this tab, so the preview app opens its windows from a stub of its own
        VCamSettingExperimentView.make = {
            AnyView(
                Form {
                    Button {
                        MacWindowManager.shared.open(VCamSettingTrackingMappingEditorView())
                    } label: {
                        Text(verbatim: "Tracking Adjustment")
                    }
                }
                .formStyle(.grouped)
            )
        }

        NSApp.mainOrFirstWindow?.title = "VCam"
    }

    /// The keys a Perfect Sync capable model exposes, plus its expressions
    private static var stubBlendShapeNames: [String] {
        let names = TrackingMappingEntry.defaultMappings(for: .blendShape).map(\.input.key)
            + TrackingMappingEntry.defaultMappings(for: .perfectSync).map(\.outputKey.key)
            + ["Neutral", "Joy", "Angry", "Sorrow", "Fun", "A", "I", "U", "E", "O"]
        var seen: Set<String> = []
        return names.filter { seen.insert($0).inserted }
    }
}
