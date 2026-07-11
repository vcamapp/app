import SwiftUI
import VCamEntity
import VCamCamera
import AVFoundation

public struct VCamSettingView: View {
    public enum Tab: Hashable, Identifiable, CaseIterable {
        case general
        case rendering
        case tracking
        case virtualCamera
        case integration
        case experiment
#if ENABLE_ACCOUNT
        case account
#endif
        case vcam

        public var id: Self { self }

        var title: String {
            switch self {
            case .general:
                String(localized: .general)
            case .rendering:
                String(localized: .rendering)
            case .tracking:
                String(localized: .tracking)
            case .virtualCamera:
                String(localized: .virtualCamera)
            case .integration:
                String(localized: .integration)
            case .experiment:
                String(localized: .experiment)
#if ENABLE_ACCOUNT
            case .account:
                String(localized: .license)
#endif
            case .vcam:
                Bundle.main.displayName
            }
        }

        var icon: Image {
            switch self {
            case .general:
                Image(systemName: "hammer.fill")
            case .rendering:
                Image(systemName: "display")
            case .tracking:
                Image(systemName: "figure")
            case .virtualCamera:
                Image(systemName: "camera.fill")
            case .integration:
                Image(systemName: "app.connected.to.app.below.fill")
            case .experiment:
                Image(systemName: "exclamationmark.triangle.fill")
#if ENABLE_ACCOUNT
            case .account:
                Image(systemName: "checkmark.seal.fill")
#endif
            case .vcam:
                Image(systemName: "info.circle.fill")
            }
        }
    }

    @State var tab: Tab = .general

    @Bindable private var recorder = VideoRecorder.shared

    public init(tab: Tab = .general) {
        self._tab = State(initialValue: tab)
    }

    public var body: some View {
        HStack {
            List(Tab.allCases, selection: $tab) { tab in
                Label {
                    Text(verbatim: tab.title)
                        .font(.callout)
                } icon: {
                    tab.icon
                }
                .accessibilityIdentifier("settings.tab.\(tab)")
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
#if ENABLE_ACCOUNT
                case .account:
                    VCamSettingLicenseView()
#endif
                case .vcam:
                    VCamSettingVCamView.make()
                }
            }
            .frame(minWidth: 500, maxHeight: .infinity, alignment: .top)
        }
        .disabled(recorder.isRecording)
        .rootView()
    }
}

extension VCamSettingView: MacWindow {
    public var windowTitle: String { String(localized: .settings) }

    public func configureWindow(_ window: NSWindow) -> NSWindow {
        window.level = .floating
        return window
    }
}

#Preview {
    VCamSettingView(tab: .general)
}
