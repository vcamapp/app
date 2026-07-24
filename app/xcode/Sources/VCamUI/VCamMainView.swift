//
//  VCamMainView.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/02/20.
//

import SwiftUI
import VCamEntity
import VCamCamera
import VCamTracking
import VCamData

public struct VCamMainView: View {
    public init() {}

    @Environment(UniState.self) private var uniState

    @State private var isCameraExtensionDisallow = false

    public var body: some View {
        @Bindable var state = uniState

        VStack(alignment: .leading) {
            if isCameraExtensionDisallow {
                Button {
                    MacWindowManager.shared.open(VCamSettingView(tab: .virtualCamera))
                } label: {
                    Image(systemName: "exclamationmark.triangle")
                    Text(.cameraExtensionAwaitingUserApproval)
                }
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            let calibrateButton = FlatButton {
                Tracking.shared.resetCalibration()
            } label: {
                Text(.calibrate)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .flatButtonStyle(.label)
            .help(.helpCalibrate)

            HStack {
                if #available(macOS 26.0, *) {
                    GroupBox {
                        SelectAllTextField(placeholder: String(localized: .message), text: $state.message)
                            .padding(.horizontal, 8)
                    }

                    GroupBox {
                        calibrateButton
                            .controlSize(.mini)
                            .padding(.vertical, -1.5)
                    }
                } else {
                    SelectAllTextField(placeholder: String(localized: .message), text: $state.message)

                    calibrateButton
                }
            }

            VCamShortcutGridView()
        }
        .task {
            isCameraExtensionDisallow = await CameraExtension().status().isAwaitingUserApproval
        }
    }
}

#Preview {
    VCamMainView()
        .padding(4)
}

#Preview {
    VCamShortcutGridView(shortcutManager: VCamShortcutManager(shortcuts: [
        .create(),
        .create(),
    ]))
    .padding(4)
}
