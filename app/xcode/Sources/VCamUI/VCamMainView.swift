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

    private enum CalibrationTarget: String, Identifiable {
        case face, hand
        var id: String { rawValue }
    }

    @State private var isCameraExtensionDisallow = false
    @State private var calibrationTarget: CalibrationTarget?

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

            let calibrateButton = Menu {
                Button {
                    calibrationTarget = .face
                } label: {
                    Text(.faceTracking)
                }
                let handAvailability = HandTrackingCalibrationView.availability()
                Button {
                    calibrationTarget = .hand
                } label: {
                    Text(.handTracking)
                }
                .disabled(!handAvailability.isAvailable)
                if case .unavailable(let reason?) = handAvailability {
                    Text(verbatim: reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } label: {
                Text(.calibrate)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .contentShape(Rectangle())
            .fixedSize()
            .help(.helpCalibrate)
            .popover(item: $calibrationTarget, arrowEdge: .bottom) { target in
                switch target {
                case .face:
                    FaceTrackingCalibrationView()
                case .hand:
                    HandTrackingCalibrationView.make()
                }
            }

            HStack {
                let subtitleField = HStack(spacing: 4) {
                    CommitTextField(placeholder: String(localized: .subtitle), text: $state.subtitle)
                    SubtitleStyleButton()
                }
                if #available(macOS 26.0, *) {
                    GroupBox {
                        subtitleField
                            .padding(.horizontal, 8)
                    }

                    GroupBox {
                        // controlSize would also shrink the menu item fonts,
                        // so adjust the height with padding alone
                        calibrateButton
                            .padding(.vertical, -1.5)
                    }
                } else {
                    subtitleField
                    calibrateButton
                }
            }

            VCamShortcutGridView()
        }
        .task {
            isCameraExtensionDisallow = await VirtualCamera.backend?.status().isAwaitingUserApproval == true
        }
    }
}

/// Opens the text editor for the subtitle, so its look is configured where it is typed.
/// Uses the same flat chip as the shortcut buttons below the field.
private struct SubtitleStyleButton: View {
    var body: some View {
        FlatButton {
            SubtitleTextObject.showStyleEditor()
        } label: {
            Image(systemName: "textformat")
        }
        .flatButtonStyle(.filled())
        .help(Text(.subtitleStyle))
        .accessibilityLabel(Text(.subtitleStyle))
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
