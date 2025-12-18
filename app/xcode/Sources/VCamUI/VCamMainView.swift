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
import VCamBridge

public struct VCamMainView: View {
    public init() {}
    
    @ExternalStateBinding(.message) private var message

    @State private var isCameraExtensionDisallow = false

    public var body: some View {
        VStack(alignment: .leading) {
            if isCameraExtensionDisallow {
                Button {
                    MacWindowManager.shared.open(VCamSettingView(tab: .virtualCamera))
                } label: {
                    Image(systemName: "exclamationmark.triangle")
                    Text(L10n.cameraExtensionAwaitingUserApproval.key, bundle: .localize)
                }
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            let calibrateButton = FlatButton {
                Tracking.shared.resetCalibration()
            } label: {
                Text(L10n.calibrate.key, bundle: .localize)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .flatButtonStyle(.label)
            .help(L10n.helpCalibrate.text)

            HStack {
                if #available(macOS 26.0, *) {
                    GroupBox {
                        SelectAllTextField(placeholder: L10n.message.text, text: $message)
                            .padding(.horizontal, 8)
                    }

                    GroupBox {
                        calibrateButton
                            .controlSize(.mini)
                            .padding(.vertical, -1.5)
                    }
                } else {
                    SelectAllTextField(placeholder: L10n.message.text, text: $message)

                    calibrateButton
                }
            }

            VCamShortcutGridView()
        }
        .task {
            if let property = try? await CameraExtension().extensionProperties() {
                isCameraExtensionDisallow = property.isAwaitingUserApproval
            }
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
