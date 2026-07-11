import SwiftUI
import VCamData

public struct VCamSettingGeneralView: View {
    public init() {}

    @AppStorage(key: .useHMirror) var useHMirror
    @AppStorage(key: .useAutoConvertVRM1) var useAutoConvertVRM1
    @Environment(UniState.self) private var uniState

    public var body: some View {
        @Bindable var state = uniState

        Form {
            Section {
#if FEATURE_3
                Toggle(isOn: $state.useAutoMode) {
                    Text(.playIdleMotions)
                }
                Toggle(isOn: $state.useCombineMesh) {
                    Text(.optimizeMeshes)
                }
                .help(.helpMesh)
                Toggle(isOn: $useAutoConvertVRM1) {
                    Text(.enableAutoConvertingToVRM1)
                }
#endif
                Toggle(isOn: $useHMirror) {
                    Text(.flipScreen)
                }
                Toggle(isOn: $state.useAddToMacOSMenuBar) {
                    Text(.addToMacOSMenuBar)
                }
            }

            LanguageSettingsSection()
        }
        .formStyle(.grouped)
        .onChange(of: uniState.useAddToMacOSMenuBar) { _, newValue in
            VCamSystem.shared.windowManager.isMacOSMenubarVisible = newValue
        }
    }
}

#Preview {
    VCamSettingGeneralView()
}
