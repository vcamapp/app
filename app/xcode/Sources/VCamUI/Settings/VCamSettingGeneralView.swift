//
//  VCamSettingGeneralView.swift
//
//
//  Created by Tatsuya Tanaka on 2023/02/14.
//

import SwiftUI
import VCamLocalization

public struct VCamSettingGeneralView: View {
    public init() {}

    @AppStorage(key: .useHMirror) var useHMirror
    @AppStorage(key: .useAutoConvertVRM1) var useAutoConvertVRM1
    @AppStorage(key: .locale) var locale

    @Environment(UniState.self) private var uniState

    public var body: some View {
        @Bindable var state = uniState

        Form {
            Section {
#if FEATURE_3
                Toggle(isOn: $state.useAutoMode) {
                    Text(L10n.playIdleMotions.key, bundle: .localize)
                }
                Toggle(isOn: $state.useCombineMesh) {
                    Text(L10n.optimizeMeshes.key, bundle: .localize)
                }
                .help(L10n.helpMesh.text)
                Toggle(isOn: $useAutoConvertVRM1) {
                    Text(L10n.enableAutoConvertingToVRM1.key, bundle: .localize)
                }
#endif
                Toggle(isOn: $useHMirror) {
                    Text(L10n.flipScreen.key, bundle: .localize)
                }
                Toggle(isOn: $state.useAddToMacOSMenuBar) {
                    Text(L10n.addToMacOSMenuBar.key, bundle: .localize)
                }
            }

            Section {
                Picker("Language / 言語", selection: $locale.map(get: LanguageList.init(locale:), set: \.rawValue)) {
                    ForEach(LanguageList.allCases) { lang in
                        Text(lang.name).tag(lang.rawValue)
                    }
                }
            }
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
