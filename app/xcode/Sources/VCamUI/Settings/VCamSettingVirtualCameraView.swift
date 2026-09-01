import SwiftUI
import VCamCamera

public struct VCamSettingVirtualCameraView: View {
    public init() {}

    @State private var isCameraExtensionInstalled = false
    @State private var isCameraExtensionStarting = false
    @State private var isAwaitingUserApproval = false

    @State private var task: Task<Void, Never>?

    public var body: some View {
        Form {
            Section {
                VStack {
                    HStack {
                        Image(systemName: "info.circle")
                        Text(isCameraExtensionStarting ? .cameraExtensionWorking : .cameraExtensionNotWorking)
                    }
                    .frame(maxWidth: .infinity)

                    if !isCameraExtensionStarting, isCameraExtensionInstalled {
                        Text(.pleaseRestartMacToFix)
                            .font(.footnote)
                            .opacity(0.5)
                    }
                }
            }

            if isAwaitingUserApproval {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                    Link(destination: .cameraExtension) {
                        Text(.cameraExtensionAwaitingUserApproval)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            Section {
                VStack {
                    HStack {
                        if isCameraExtensionInstalled {
                            Button {
                                runExtensionTask {
                                    try await uninstallExtension(isAlertShown: false)
                                    try await installExtension()
                                }
                            } label: {
                                Text(.reinstall)
                            }

                            Button {
                                runExtensionTask {
                                    try await uninstallExtension(isAlertShown: true)
                                }
                            } label: {
                                Text(.uninstall)
                            }
                        } else {
                            Button {
                                runExtensionTask {
                                    try await installExtension()
                                }
                            } label: {
                                Text(.install)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    Text(.noteEnableNewCameraExtension)
                        .font(.footnote)
                        .opacity(0.5)
                }
            }

            Section {
                Link(destination: URL(string: String(localized: .docsURLForVirtualCamera))!) {
                    Text(.seeDocumentation)
                        .font(.footnote)
                }
            }
            .task {
                guard let virtualCamera = VirtualCamera.backend else { return }
                isCameraExtensionStarting = virtualCamera.isRunning
                let status = await virtualCamera.status()
                isCameraExtensionInstalled = status.isInstalled
                isAwaitingUserApproval = status.isAwaitingUserApproval
            }
        }
        .formStyle(.grouped)
    }
}

extension VCamSettingVirtualCameraView {
    private func runExtensionTask(_ operation: @escaping @MainActor () async throws -> Void) {
        task?.cancel()
        task = Task {
            do {
                try await operation()
            } catch {
                // Include the error domain and code so OS-side failures are identifiable from support inquiries
                let osError = error as NSError
                await VCamAlert.showModal(title: String(localized: .failure), message: "\(error.localizedDescription) (\(osError.domain) \(osError.code))", canCancel: false)
            }
        }
    }

    @MainActor
    private func installExtension() async throws {
        guard let virtualCamera = VirtualCamera.backend else { return }
        guard virtualCamera.isInstallable else {
            await VCamAlert.showModal(title: String(localized: .failure), message: String(localized: .moveAppToApplicationsFolder), canCancel: false)
            return
        }
        NSWorkspace.shared.open(.cameraExtension)
        let result = try await virtualCamera.install()
        isCameraExtensionInstalled = true
        isCameraExtensionStarting = await virtualCamera.installAndStart()
        let message = result == .completesAfterReboot ? String(localized: .restartMacToCompleteCameraExtensionSetup) : String(localized: .restartAfterInstalling)
        await VCamAlert.showModal(title: String(localized: .success), message: message, canCancel: false)
    }

    @MainActor
    private func uninstallExtension(isAlertShown: Bool) async throws {
        guard let virtualCamera = VirtualCamera.backend else { return }
        try await virtualCamera.uninstall()
        isCameraExtensionInstalled = false
        isCameraExtensionStarting = await virtualCamera.installAndStart()
        if isAlertShown {
            await VCamAlert.showModal(title: String(localized: .success), message: String(localized: .completeUninstalling), canCancel: false)
        }
    }
}

extension URL {
    static var cameraExtension: URL {
        URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences?extensionPointIdentifier=com.apple.system_extension.cmio.extension-point")!
    }
}

#Preview {
    VCamSettingVirtualCameraView()
        .padding()
}
