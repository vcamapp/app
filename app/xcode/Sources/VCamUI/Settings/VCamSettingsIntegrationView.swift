//
//  VCamSettingsIntegrationView.swift
//
//
//  Created by Tatsuya Tanaka on 2023/01/05.
//

import SwiftUI
import VCamTracking
import VCamBridge
import VCamLocalization
import VCamData
import Network

public struct VCamSettingsIntegrationView: View {
    public init() {}

    @AppStorage(key: .integrationFacialMocapIp) private var integrationFacialMocapIp
    @AppStorage(key: .integrationVCamMocap) private var integrationVCamMocap
    @AppStorage(key: .mocapNetworkInterpolation) private var mocapNetworkInterpolation

    @Bindable private var facialMocapReceiver = Tracking.shared.iFacialMocapReceiver

    private var facialMocapConnectTitle: LocalizedStringKey {
        switch facialMocapReceiver.connectionStatus {
        case .disconnected: return L10n.connect.key
        case .connecting: return L10n.connecting.key
        case .connected: return L10n.disconnect.key
        }
    }

    public var body: some View {
        Form {
            if let ipAddress = NWInterface.InterfaceType.wiredEthernet.ipv4 ?? NWInterface.InterfaceType.wifi.ipv4 {
                FeatureView(title: "Info.") {
                    HStack {
                        Text("IP:")
                        Text(ipAddress)
                    }
                }
            }
            FeatureView(title: "VCamMocap") {
                LabeledContent {
                    VCamMotionReceiverStatusView()

                    Toggle(isOn: $integrationVCamMocap) {
                        Text(L10n.enable.key, bundle: .localize)
                    }
                    .labelsHidden()
                    .toggleStyle(.switch)
                } label: {
                    Text(L10n.enable.key, bundle: .localize)
                }
                .onChange(of: integrationVCamMocap) { _, newValue in
                    Task {
                        if newValue {
                            try await Tracking.shared.startVCamMotionReceiver()
                        } else {
                            Tracking.shared.vcamMotionReceiver.stop()
                        }
                    }
                }
            }
            FeatureView(title: "iFacialMocap") {
                LabeledContent {
                    FacialMocapReceiverStatusView()

                    TextField(text: $integrationFacialMocapIp) {
                        Text(verbatim: "IP")
                    }
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()

                    Button {
                        Task {
                            if facialMocapReceiver.connectionStatus == .disconnected {
                                try await Tracking.shared.iFacialMocapReceiver.connect(ip: integrationFacialMocapIp)
                            } else {
                                await Tracking.shared.iFacialMocapReceiver.stop()
                            }
                        }
                    } label: {
                        Text(facialMocapConnectTitle, bundle: .localize)
                    }
                } label: {
                    Text(verbatim: "IP")
                }
            }
            Section {
                ValueEditField(L10n.mocapNetworkInterpolation.key, value: $mocapNetworkInterpolation.map(), type: .slider(0...1.0)) {
                    Text($0, format: .percent.precision(.fractionLength(2)))
                }
                Text(L10n.mocapNetworkInterpolationHelp.key, bundle: .localize)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

#if FEATURE_3
#if ENABLE_MOCOPI
            MocopiSettingView()
#endif
#endif
        }
        .formStyle(.grouped)
    }
}

private struct ReceiverStatusView: View {
    let connectionStatus: ConnectionStatus

    private var statusText: LocalizedStringKey {
        switch connectionStatus {
        case .disconnected: return L10n.disconnected.key
        case .connecting: return L10n.connecting.key
        case .connected: return L10n.connected.key
        }
    }

    var body: some View {
        Text(statusText, bundle: .localize)
            .foregroundStyle(connectionStatus == .connected ? Color.accentColor : .secondary)
            .font(.callout)
            .fontWeight(.medium)
            .opacity(connectionStatus == .connected ? 1.0 : 0.6)
    }
}

private struct VCamMotionReceiverStatusView: View {
    @Bindable private var receiver = Tracking.shared.vcamMotionReceiver

    var body: some View {
        ReceiverStatusView(connectionStatus: receiver.connectionStatus)
    }
}

private struct FacialMocapReceiverStatusView: View {
    @Bindable private var receiver = Tracking.shared.iFacialMocapReceiver

    var body: some View {
        ReceiverStatusView(connectionStatus: receiver.connectionStatus)
    }
}

#if ENABLE_MOCOPI
private struct MocopiSettingView: View {
    @AppStorage(key: .integrationMocopi) private var integrationMocopi

    var body: some View {
        VCamSettingsIntegrationView.FeatureView(title: "mocopi") {
            Toggle(isOn: $integrationMocopi) {
                Text(L10n.enable.key, bundle: .localize)
            }
        }
        .help(L10n.helpMocopIP.text)
        .onChange(of: integrationMocopi) { _, newValue in
            UniBridge.shared.useFullTracking(newValue)
            Tracking.shared.setHandTrackingMethod(.mocopi)
        }
    }
}
#endif

private extension VCamSettingsIntegrationView {
    struct FeatureView<Content: View>: View {
        init(title: String, @ViewBuilder content: () -> Content) {
            self.title = title
            self.content = content()
        }

        let title: String
        let content: Content

        var body: some View {
            Section {
                content
                    .frame(maxWidth: .infinity)
            } header: {
                Text(title)
            }
        }
    }
}

#Preview {
    VCamSettingsIntegrationView()
}
