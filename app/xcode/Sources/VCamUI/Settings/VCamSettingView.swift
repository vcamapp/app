//
//  VCamSettingView.swift
//
//
//  Created by Tatsuya Tanaka on 2023/02/12.
//

import SwiftUI
import VCamEntity
import VCamCamera
import VCamLocalization
import AVFoundation

public struct VCamSettingView: View {
    public enum Tab: Hashable, Identifiable, CaseIterable {
        case general
        case rendering
        case tracking
        case virtualCamera
        case integration
        case experiment
        case vcam

        public var id: Self { self }

        var title: LocalizedStringKey {
            switch self {
            case .general:
                L10n.general.key
            case .rendering:
                L10n.rendering.key
            case .tracking:
                L10n.tracking.key
            case .virtualCamera:
                L10n.virtualCamera.key
            case .integration:
                L10n.integration.key
            case .experiment:
                L10n.experiment.key
            case .vcam:
                LocalizedStringKey(Bundle.main.displayName)
            }
        }

        var icon: Image {
            switch self {
            case .general:
                Image(systemName: "hammer.fill")
            case .rendering:
                Image(systemName: "display")
            case .tracking:
                if #available(macOS 14, *) {
                    Image(systemName: "figure")
                } else {
                    Image(systemName: "figure.arms.open")
                }
            case .virtualCamera:
                Image(systemName: "camera.fill")
            case .integration:
                Image(systemName: "app.connected.to.app.below.fill")
            case .experiment:
                Image(systemName: "exclamationmark.triangle.fill")
            case .vcam:
                Image(systemName: "info.circle.fill")
            }
        }
    }

    @State var tab: Tab = .general

    @Bindable private var recorder = VideoRecorder.shared

    @AppStorage(key: .locale) var locale

    public init(tab: Tab = .general) {
        self._tab = State(initialValue: tab)
    }

    public var body: some View {
        HStack {
            List(Tab.allCases, selection: $tab) { tab in
                Label {
                    Text(tab.title, bundle: .localize)
                        .font(.callout)
                } icon: {
                    tab.icon
                }
            }
            .listStyle(.sidebar)
            .frame(width: 150)

            Group {
                switch tab {
                case .general:
                    VCamSettingGeneralView()
                case .rendering:
                    VCamSettingRenderingView()
                case .tracking:
                    VCamSettingTrackingView()
                case .virtualCamera:
                    VCamSettingVirtualCameraView()
                case .integration:
                    VCamSettingsIntegrationView()
                case .experiment:
                    VCamSettingExperimentView.make()
                case .vcam:
                    VCamSettingVCamView.make()
                }
            }
            .frame(minWidth: 450, maxHeight: .infinity, alignment: .top)
        }
        .environment(\.locale, locale.isEmpty ? .current : Locale(identifier: locale))
        .disabled(recorder.isRecording)
        .rootView()
    }
}

extension VCamSettingView: MacWindow {
    public var windowTitle: String { L10n.settings.text }

    public func configureWindow(_ window: NSWindow) -> NSWindow {
        window.level = .floating
        return window
    }
}

#Preview {
    VCamSettingView(tab: .general)
}
