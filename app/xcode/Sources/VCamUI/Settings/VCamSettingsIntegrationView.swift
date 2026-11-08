import SwiftUI
import VCamTracking
import VCamTrackingCore
import VCamBridge
import VCamData
import VCamEntity
import VCamLogger
import VCamRemoteControl
import Network

public struct VCamSettingsIntegrationView: View {
    public init() {}

    @AppStorage(key: .integrationFacialMocapIp) private var integrationFacialMocapIp
    @AppStorage(key: .integrationVCamMocap) private var integrationVCamMocap
    @AppStorage(key: .mocapNetworkInterpolation) private var mocapNetworkInterpolation
    @AppStorage(key: .integrationVMCProtocol) private var integrationVMCProtocol
    @AppStorage(key: .integrationExternalControl) private var integrationExternalControl
    @AppStorage(key: .integrationExternalControlNetworkAccess) private var integrationExternalControlNetworkAccess
    @AppStorage(key: .integrationExternalControlRequiresToken) private var integrationExternalControlRequiresToken

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
            if let ipAddress = NWInterface.thisMacIPv4 {
                Section {
                    LabeledContent {
                        Text(ipAddress)
                            .textSelection(.enabled)
                        CopyButton(text: ipAddress)
                    } label: {
                        Text(.thisMacIPAddress)
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
            } header: {
                Text(verbatim: "VCam Mocap / iFacialMocap")
            }

#if FEATURE_3
#if ENABLE_MOCOPI
            if RenderingFeature.supported.contains(.fullBodyTracking) {
                MocopiSettingView()
            }
#endif
#endif
            if RenderingFeature.supported.contains(.vmcProtocol) {
                VMCProtocolSettingView(integrationVMCProtocol: $integrationVMCProtocol)
            }
            if RenderingFeature.supported.contains(.externalControl) {
                ExternalControlSettingView(
                    integrationExternalControl: $integrationExternalControl,
                    integrationExternalControlNetworkAccess: $integrationExternalControlNetworkAccess,
                    integrationExternalControlRequiresToken: $integrationExternalControlRequiresToken
                )
            }
        }
        .formStyle(.grouped)
        // Rows come and go through the form only when the form that owns the setting animates it
        .animation(.default, value: integrationVMCProtocol)
        .animation(.default, value: integrationExternalControl)
        .animation(.default, value: ExternalControlServer.shared.isRunning)
        .animation(.default, value: integrationExternalControlNetworkAccess)
        .animation(.default, value: integrationExternalControlRequiresToken)
    }
}

private struct VMCProtocolSettingView: View {
    @Binding var integrationVMCProtocol: Bool
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

            if integrationVMCProtocol {
                PortRow(port: $integrationVMCProtocolPort)

                if RenderingFeature.supported.contains(.vmcProtocolFullPose) {
                    Toggle(isOn: $integrationVMCProtocolExpressions) {
                        Text(.vmcProtocolReceivesExpressions)
                    }
                    .onChange(of: integrationVMCProtocolExpressions) { _, newValue in
                        receiver.receivesExpressions = newValue
                    }
                }
            }

            Text(.vmcProtocolHelp)
                .font(.caption2)
                .foregroundStyle(.secondary)

            if !RenderingFeature.supported.contains(.vmcProtocolFullPose) {
                Text(.vmcProtocolHeadAndTorsoOnly)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: integrationVMCProtocolPort) {
            guard integrationVMCProtocol else { return }
            receiver.stop()
            do {
                try Tracking.shared.startVMCProtocolReceiver()
            } catch {
                Logger.error(error)
                integrationVMCProtocol = false
            }
        }
    }
}

private struct ExternalControlSettingView: View {
    @Binding var integrationExternalControl: Bool
    @AppStorage(key: .integrationExternalControlPort) private var integrationExternalControlPort
    @AppStorage(key: .integrationExternalControlFrameCapture) private var integrationExternalControlFrameCapture
    @AppStorage(key: .integrationExternalControlToken) private var integrationExternalControlToken
    @Binding var integrationExternalControlNetworkAccess: Bool
    @Binding var integrationExternalControlRequiresToken: Bool

    @State private var isRegenerateTokenConfirmationPresented = false

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

            if integrationExternalControl {
                PortRow(port: $integrationExternalControlPort)
            }

            VStack(spacing: 4) {
                Text(.externalControlHelp)
                    .foregroundStyle(.secondary)
                Link(destination: URL(string: String(localized: .docsURLForVCamAPI))!) {
                    Text(.seeDocumentation)
                }
            }
            .font(.caption2)

            if integrationExternalControl {
                Toggle(isOn: $integrationExternalControlNetworkAccess) {
                    Text(.externalControlAllowsNetworkAccess)
                    Text(.externalControlNetworkAccessHelp)
                }

                if integrationExternalControlNetworkAccess {
                    networkAccessRows
                }

                Toggle(isOn: $integrationExternalControlFrameCapture) {
                    Text(.externalControlAllowsFrameCapture)
                    Text(.externalControlFrameCaptureHelp)
                }
            }
        }
        .onChange(of: integrationExternalControlPort) {
            restartIfRunning()
        }
        .onChange(of: integrationExternalControlNetworkAccess, initial: true) { oldValue, newValue in
            if newValue {
                ExternalControlToken.saved()
            }
            if oldValue != newValue {
                restartIfRunning()
            }
        }
        .onChange(of: integrationExternalControlRequiresToken) {
            restartIfRunning()
        }
    }

    @ViewBuilder
    private var networkAccessRows: some View {
        if let ipAddress = NWInterface.thisMacIPv4 {
            LabeledContent {
                let address = "ws://\(ipAddress):\(integrationExternalControlPort)"
                Text(verbatim: address)
                    .textSelection(.enabled)
                CopyButton(text: address)
            } label: {
                Text(.externalControlAddress)
            }
        }

        Toggle(isOn: $integrationExternalControlRequiresToken) {
            Text(.externalControlRequiresToken)
        }

        if integrationExternalControlRequiresToken {
            LabeledContent {
                Text(verbatim: String(repeating: "•", count: 12))
                    .foregroundStyle(.secondary)
                CopyButton(text: integrationExternalControlToken)
                Button {
                    isRegenerateTokenConfirmationPresented = true
                } label: {
                    Text(.externalControlRegenerateToken)
                }
            } label: {
                Text(.externalControlToken)
                Text(.externalControlTokenHelp)
            }
            .confirmationDialog(Text(.externalControlRegenerateToken), isPresented: $isRegenerateTokenConfirmationPresented) {
                Button(role: .cancel) {
                } label: {
                    Text(.cancel)
                }

                Button(role: .destructive) {
                    ExternalControlToken.regenerate()
                    // Drops the clients that connected with the old token
                    restartIfRunning()
                } label: {
                    Text(.externalControlRegenerateToken)
                }
            } message: {
                Text(.confirmRegenerateExternalControlToken)
            }
        } else {
            Label {
                Text(.externalControlNoTokenWarning)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
            }
            .font(.callout)
            .foregroundStyle(.orange)
        }
    }

    private func restartIfRunning() {
        guard ExternalControlServer.shared.isRunning else { return }
        Task {
            do {
                try await ExternalControlServer.shared.restartWithSavedPort()
            } catch {
                Logger.error(error)
                integrationExternalControl = false
            }
        }
    }
}

private struct CopyButton: View {
    let text: String

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
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

private extension NWInterface {
    static var thisMacIPv4: String? {
        InterfaceType.wiredEthernet.ipv4 ?? InterfaceType.wifi.ipv4
    }
}

/// Starts and stops a listener with its toggle, next to its status
private struct EnableToggleRow<Status: View>: View {
    @Binding var isOn: Bool
    let start: () throws -> Void
    let stop: () -> Void
    @ViewBuilder let status: Status

    var body: some View {
        // The status rides at the end of the label: a switch with its label hidden exposes no press action to accessibility
        Toggle(isOn: $isOn) {
            HStack {
                Text(.enable)
                Spacer()
                status
            }
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

private struct PortRow: View {
    @Binding var port: Int

    var body: some View {
        LabeledContent {
            TextField(value: $port, format: .number.grouping(.never)) {
                Text(verbatim: "Port")
            }
            .textFieldStyle(.roundedBorder)
            .labelsHidden()
            .frame(maxWidth: 100)
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
