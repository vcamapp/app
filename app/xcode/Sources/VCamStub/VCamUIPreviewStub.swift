import AppKit
import SwiftUI
import VCamBridge
import VCamData
import VCamTracking
import VCamUI
import VCamTrackingCore

public enum VCamUIPreviewStub {
    @MainActor
    public static func stub() {
        MainTexture.shared.setTexture(MTLTextureStub.makeMainTexture())

        let engineView = NSView()
        engineView.wantsLayer = true
        engineView.layer?.backgroundColor = NSColor.red.cgColor
        NSApp.windows.first?.contentView = engineView

        UniBridgeStub.shared.stub(.shared)

        // Stands in for the model load that fills these from the engine
        UniState.shared.initializeFromEngine()
        UniState.shared.avatarBlendShapeNames = stubBlendShapeNames
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

    /// Stands in for a Perfect Sync model: the 52 ARKit shapes plus the VRM groups
    private static var stubBlendShapeNames: [String] {
        TrackingMappingEntry.DefaultMappingDefinition.perfectSyncFacialDefinitions.map(\.key)
            + ["Neutral", "Joy", "Angry", "Sorrow", "Fun", "A", "I", "U", "E", "O"]
    }
}
