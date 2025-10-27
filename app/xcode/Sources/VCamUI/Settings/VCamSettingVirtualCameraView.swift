//
//  VCamSettingVirtualCameraView.swift
//
//
//  Created by Tatsuya Tanaka on 2023/08/16.
//

import SwiftUI
import VCamLocalization
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
                        Text(isCameraExtensionStarting ? L10n.cameraExtensionWorking.key : L10n.cameraExtensionNotWorking.key, bundle: .localize)
                    }
                    .frame(maxWidth: .infinity)

                    if !isCameraExtensionStarting, isCameraExtensionInstalled {
                        Text(L10n.pleaseRestartMacToFix.key, bundle: .localize)
                            .font(.footnote)
                            .opacity(0.5)
                    }
                }
            }

            if isAwaitingUserApproval {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                    Link(destination: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!) {
                        Text(L10n.cameraExtensionAwaitingUserApproval.key, bundle: .localize)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            Section {
                VStack {
                    HStack {
                        if isCameraExtensionInstalled {
                            Button {
                                task?.cancel()
                                task = Task {
                                    do {
                                        try await uninstallExtension(isAlertShown: false)
                                        try await installExtension()
                                    } catch {
                                        await VCamAlert.showModal(title: L10n.failure.text, message: error.localizedDescription, canCancel: false)
                                    }
                                }
                            } label: {
                                Text(L10n.reinstall.key, bundle: .localize)
                            }
                            
                            Button {
                                task?.cancel()
                                task = Task {
                                    do {
                                        try await uninstallExtension(isAlertShown: true)
                                    } catch {
                                        await VCamAlert.showModal(title: L10n.failure.text, message: error.localizedDescription, canCancel: false)
                                    }
                                }
                            } label: {
                                Text(L10n.uninstall.key, bundle: .localize)
                            }
                        } else {
                            Button {
                                task?.cancel()
                                task = Task {
                                    do {
                                        try await installExtension()
                                    } catch {
                                        await VCamAlert.showModal(title: L10n.failure.text, message: error.localizedDescription, canCancel: false)
                                    }
                                }
                            } label: {
                                Text(L10n.install.key, bundle: .localize)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    Text(L10n.noteEnableNewCameraExtension.key, bundle: .localize)
                        .font(.footnote)
                        .opacity(0.5)
                }
            }

            Section {
                Link(destination: URL(string: L10n.docsURLForVirtualCamera.text)!) {
                    Text(L10n.seeDocumentation.key, bundle: .localize)
                        .font(.footnote)
                }
            }
            .task {
                isCameraExtensionInstalled = CoreMediaSinkStream.isInstalled
                isCameraExtensionStarting = VirtualCameraManager.shared.sinkStream.isStarting
                if let property = try? await CameraExtension().extensionProperties() {
                    isAwaitingUserApproval = property.isAwaitingUserApproval
                }
            }
        }
        .formStyle(.grouped)
    }
}

extension VCamSettingVirtualCameraView {
    @MainActor
    private func installExtension() async throws {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!)
        try await CameraExtension().installExtension()
        isCameraExtensionInstalled = true
        isCameraExtensionStarting = await VirtualCameraManager.shared.installAndStartCameraExtension()
        await VCamAlert.showModal(title: L10n.success.text, message: L10n.restartAfterInstalling.text, canCancel: false)
    }

    @MainActor
    private func uninstallExtension(isAlertShown: Bool) async throws {
        try await CameraExtension().uninstallExtension()
        isCameraExtensionInstalled = false
        isCameraExtensionStarting = await VirtualCameraManager.shared.installAndStartCameraExtension()
        if isAlertShown {
            await VCamAlert.showModal(title: L10n.success.text, message: L10n.completeUninstalling.text, canCancel: false)
        }
    }
}

#Preview {
    VCamSettingVirtualCameraView()
        .padding()
}
