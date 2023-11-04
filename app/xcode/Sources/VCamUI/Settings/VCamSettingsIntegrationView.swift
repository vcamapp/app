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
import Network

public struct VCamSettingsIntegrationView: View {
    public init() {}

    @AppStorage(key: .integrationFacialMocapIp) private var integrationFacialMocapIp
    @AppStorage(key: .integrationVCamMocap) private var integrationVCamMocap

    @ObservedObject private var facialMocapReceiver = Tracking.shared.iFacialMocapReceiver

    private var facialMocapConnectTitle: LocalizedStringKey {
        switch facialMocapReceiver.connectionStatus {
        case .disconnected: return L10n.connect.key
        case .connecting: return L10n.connecting.key
        case .connected: return L10n.disconnect.key
        }
    }

    public var body: some View {
        VStack {
            if let ipAddress = NWInterface.InterfaceType.wiredEthernet.ipv4 ?? NWInterface.InterfaceType.wifi.ipv4 {
                FeatureView(title: "Info.") {
                    HStack {
                        Text("IP:")
                        Text(ipAddress)
                    }
                }
            }
            FeatureView(title: "VCamMocap") {
                Toggle(isOn: $integrationVCamMocap) {
                    Text(L10n.enable.key, bundle: .localize)
                }
                .onChange(of: integrationVCamMocap) { newValue in
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
                HStack {
                    TextField("IP", text: $integrationFacialMocapIp)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 128)

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
                }
            }

#if ENABLE_MOCOPI
            MocopiSettingView()
#endif
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if ENABLE_MOCOPI
private struct MocopiSettingView: View {
    @AppStorage(key: .integrationMocopi) private var integrationMocopi

    @ExternalStateBinding(.useFullTracking) private var useFullTracking

    var body: some View {
        VCamSettingsIntegrationView.FeatureView(title: "mocopi") {
            Toggle(isOn: $integrationMocopi) {
                Text(L10n.enable.key, bundle: .localize)
            }
        }
        .help(L10n.helpMocopIP.text)
        .onChange(of: integrationMocopi) { newValue in
            useFullTracking = newValue
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
            GroupBox {
                GroupBox(title) {
                    content
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

#Preview {
    VCamSettingsIntegrationView()
}
