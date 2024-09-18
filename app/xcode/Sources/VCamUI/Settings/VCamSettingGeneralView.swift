//
//  VCamSettingGeneralView.swift
//
//
//  Created by Tatsuya Tanaka on 2023/02/14.
//

import SwiftUI
import VCamLocalization
import VCamBridge

public struct VCamSettingGeneralView: View {
    public init() {}

    @AppStorage(key: .useHMirror) var useHMirror
    @AppStorage(key: .useAutoConvertVRM1) var useAutoConvertVRM1
    @AppStorage(key: .locale) var locale

    @ExternalStateBinding(.useAutoMode) private var useAutoMode: Bool
    @ExternalStateBinding(.useCombineMesh) private var useCombineMesh: Bool
    @ExternalStateBinding(.useAddToMacOSMenuBar) private var useAddToMacOSMenuBar: Bool

    public var body: some View {
        GroupBox {
            Form {
                Toggle(isOn: $useAutoMode) {
                    Text(L10n.playIdleMotions.key, bundle: .localize)
                }
                Toggle(isOn: $useCombineMesh) {
                    Text(L10n.optimizeMeshes.key, bundle: .localize)
                }
                .help(L10n.helpMesh.text)
                Toggle(isOn: $useAutoConvertVRM1) {
                    Text(L10n.enableAutoConvertingToVRM1.key, bundle: .localize)
                }
                Toggle(isOn: $useHMirror) {
                    Text(L10n.flipScreen.key, bundle: .localize)
                }
                Toggle(isOn: $useAddToMacOSMenuBar) {
                    Text(L10n.addToMacOSMenuBar.key, bundle: .localize)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: useAddToMacOSMenuBar) { _, newValue in
            VCamSystem.shared.windowManager.isMacOSMenubarVisible = newValue
        }

        GroupBox {
            Form {
                Picker("Language / 言語", selection: $locale.map(get: LanguageList.init(locale:), set: \.rawValue)) {
                    ForEach(LanguageList.allCases) { lang in
                        Text(lang.name).tag(lang.rawValue)
                    }
                }
            }
        }
    }
}

#Preview {
    VCamSettingGeneralView()
}
