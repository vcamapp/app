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

public struct VCamMainView: View {
    public init() {}
    
    @UniState(.message, name: "message") private var message

    @State private var isCameraExtensionDisallow = false

    public var body: some View {
        VStack(alignment: .leading) {
            if isCameraExtensionDisallow {
                Button {
                    MacWindowManager.shared.openSettingsVirtualCamera()
                } label: {
                    Image(systemName: "exclamationmark.triangle")
                    Text(L10n.cameraExtensionAwaitingUserApproval.key, bundle: .localize)
                }
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            HStack {
                SelectAllTextField(placeholder: L10n.message.text, text: $message)
                FlatButton {
                    Tracking.shared.resetCalibration()
                } label: {
                    Text(L10n.calibrate.key, bundle: .localize)
                        .font(.callout)
                }
                .flatButtonStyle(.label)
                .help(L10n.helpCalibrate.text)
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
