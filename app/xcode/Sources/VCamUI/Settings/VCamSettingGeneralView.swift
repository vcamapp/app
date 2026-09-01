import SwiftUI
import VCamData
import VCamEntity

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
                if RenderingFeature.supported.contains(.meshOptimization) {
                    Toggle(isOn: $state.useCombineMesh) {
                        Text(.optimizeMeshes)
                    }
                    .help(.helpMesh)
                }
                if uniState.value(for: .useURP) {
                    // URP doesn't support MToon of VRM 0.x, so the conversion is always enabled
                    Toggle(isOn: .constant(true)) {
                        VStack(alignment: .leading) {
                            Text(.enableAutoConvertingToVRM1)
                            Text(.alwaysEnabledWhileUsingURP)
                                .font(.footnote)
                                .opacity(0.5)
                        }
                    }
                    .disabled(true)
                } else {
                    Toggle(isOn: $useAutoConvertVRM1) {
                        Text(.enableAutoConvertingToVRM1)
                    }
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
