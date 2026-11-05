import SwiftUI
import VCamTracking
import VCamTrackingCore
import VCamBridge
import VCamData
import VCamEntity
import VCamLogger
#if FEATURE_API
import VCamRemoteControl
#endif
import Network

public struct VCamSettingsIntegrationView: View {
    public init() {}

    @AppStorage(key: .integrationFacialMocapIp) private var integrationFacialMocapIp
    @AppStorage(key: .integrationVCamMocap) private var integrationVCamMocap
    @AppStorage(key: .mocapNetworkInterpolation) private var mocapNetworkInterpolation

    @Bindable private var facialMocapReceiver = Tracking.shared.iFacialMocapReceiver

    private var facialMocapConnectTitle: LocalizedStringResource {
        switch facialMocapReceiver.connectionStatus {
        case .disconnected: return .connect
        case .connecting: return .connecting
        case .connected: return .disconnect
        }
    }

    public var body: some View {
        Form {
            if let ipAddress = NWInterface.InterfaceType.wiredEthernet.ipv4 ?? NWInterface.InterfaceType.wifi.ipv4 {
                FeatureView(title: "Info.") {
                    HStack {
                        Text(verbatim: "IP:")
                        Text(ipAddress)
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(ipAddress, forType: .string)
                        } label: {
                            Label {
                                Text(.copy)
                            } icon: {
                                Image(systemName: "doc.on.doc")
                            }
                            .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.borderless)
                        .help(Text(.copy))
                    }
                }
            }
            FeatureView(title: "VCam Mocap") {
                EnableToggleRow(isOn: $integrationVCamMocap) {
                    try Tracking.shared.startVCamMotionReceiver()
                } stop: {
                    Tracking.shared.vcamMotionReceiver.stop()
                } status: {
                    VCamMotionReceiverStatusView()
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
                                do {
                                    try await Tracking.shared.iFacialMocapReceiver.connect(ip: integrationFacialMocapIp)
                                } catch {
                                    Logger.error(error)
                                }
                            } else {
                                await Tracking.shared.iFacialMocapReceiver.stop()
                            }
                        }
                    } label: {
                        Text(facialMocapConnectTitle)
                    }
                } label: {
                    Text(verbatim: "IP")
                }
            }
            Section {
                // The slider eases in, so its position says little about the delay it actually adds
                ValueEditField(.mocapNetworkInterpolation, value: $mocapNetworkInterpolation.map(), type: .slider(0...1.0)) {
                    Text(Measurement(value: TrackingSmoothing(value: $0).bufferDelay * 1000, unit: UnitDuration.milliseconds),
                         format: .measurement(width: .abbreviated, numberFormatStyle: .number.precision(.fractionLength(0))))
                }
                Text(.mocapNetworkInterpolationHelp)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

#if FEATURE_3
#if ENABLE_MOCOPI
            if RenderingFeature.supported.contains(.fullBodyTracking) {
                MocopiSettingView()
            }
#endif
#endif
            if RenderingFeature.supported.contains(.vmcProtocol) {
                VMCProtocolSettingView()
            }
#if FEATURE_API
            ExternalControlSettingView()
#endif
        }
        .formStyle(.grouped)
    }
}

private struct VMCProtocolSettingView: View {
    @AppStorage(key: .integrationVMCProtocol) private var integrationVMCProtocol
    @AppStorage(key: .integrationVMCProtocolPort) private var integrationVMCProtocolPort
    @AppStorage(key: .integrationVMCProtocolExpressions) private var integrationVMCProtocolExpressions

    @Bindable private var receiver = Tracking.shared.vmcProtocolReceiver

    var body: some View {
        VCamSettingsIntegrationView.FeatureView(title: "VMC Protocol") {
            EnableToggleRow(isOn: $integrationVMCProtocol) {
                try Tracking.shared.startVMCProtocolReceiver()
            } stop: {
                receiver.stop()
            } status: {
                ReceiverStatusView(connectionStatus: receiver.connectionStatus)
            }

            PortRow(port: $integrationVMCProtocolPort, isLocked: integrationVMCProtocol)

            Toggle(isOn: $integrationVMCProtocolExpressions) {
                Text(.vmcProtocolReceivesExpressions)
            }
            .onChange(of: integrationVMCProtocolExpressions) { _, newValue in
                receiver.receivesExpressions = newValue
            }

            Text(.vmcProtocolHelp)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

#if FEATURE_API
private struct ExternalControlSettingView: View {
    @AppStorage(key: .integrationExternalControl) private var integrationExternalControl
    @AppStorage(key: .integrationExternalControlPort) private var integrationExternalControlPort

    var body: some View {
        VCamSettingsIntegrationView.FeatureView(title: "VCam API") {
            EnableToggleRow(isOn: $integrationExternalControl) {
                try ExternalControlServer.shared.startWithSavedPort()
            } stop: {
                ExternalControlServer.shared.stop()
            } status: {
                if ExternalControlServer.shared.isRunning {
                    Text(verbatim: "ws://127.0.0.1:\(integrationExternalControlPort)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            PortRow(port: $integrationExternalControlPort, isLocked: integrationExternalControl)

            Text(.externalControlHelp)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
#endif

/// Starts and stops a listener with its toggle, next to its status
private struct EnableToggleRow<Status: View>: View {
    @Binding var isOn: Bool
    let start: () throws -> Void
    let stop: () -> Void
    @ViewBuilder let status: Status

    var body: some View {
        LabeledContent {
            status

            Toggle(isOn: $isOn) {
                Text(.enable)
            }
            .labelsHidden()
            .toggleStyle(.switch)
        } label: {
            Text(.enable)
        }
        .onChange(of: isOn) { _, newValue in
            if newValue {
                do {
                    try start()
                } catch {
                    // Roll the toggle back so the UI doesn't claim the listener is running
                    Logger.error(error)
                    isOn = false
                }
            } else {
                stop()
            }
        }
    }
}

/// Locked while the listener is enabled, since it keeps the port it started on
private struct PortRow: View {
    @Binding var port: Int
    let isLocked: Bool

    var body: some View {
        LabeledContent {
            TextField(value: $port, format: .number.grouping(.never)) {
                Text(verbatim: "Port")
            }
            .textFieldStyle(.roundedBorder)
            .labelsHidden()
            .frame(maxWidth: 100)
            .disabled(isLocked)
        } label: {
            Text(verbatim: "Port")
        }
    }
}

private struct ReceiverStatusView: View {
    let connectionStatus: ConnectionStatus

    private var statusText: LocalizedStringResource {
        switch connectionStatus {
        case .disconnected: return .disconnected
        case .connecting: return .connecting
        case .connected: return .connected
        }
    }

    var body: some View {
        Text(statusText)
            .foregroundStyle(connectionStatus == .connected ? Color.accentColor : .secondary)
            .font(.callout)
            .fontWeight(.medium)
            .opacity(connectionStatus == .connected ? 1.0 : 0.6)
    }
}

private struct VCamMotionReceiverStatusView: View {
    @Bindable private var receiver = Tracking.shared.vcamMotionReceiver

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            ReceiverStatusView(connectionStatus: receiver.connectionStatus)
            if let version = receiver.motionProtocolVersion {
                Text(version.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
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
                Text(.enable)
            }
        }
        .help(.helpMocopIP)
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
