//
//  VCamSettingLicenseView.swift
//
//
//  Created by tattn on 2025/11/17.
//

import SwiftUI
import VCamLocalization
import VCamData
import VCamEntity
import VCamLogger

struct VCamSettingLicenseView: View {
    @State var errorMessage: Text?
    @State private var isSignOutAlertPresented = false

    @Environment(\.licenseManager) private var licenseManager

    private var licenseState: LicenseState {
        licenseManager.licenseState
    }

    private var expiryDate: Date? {
        licenseManager.expiryDate
    }

    init(errorMessage: Text? = nil) {
        self._errorMessage = State(initialValue: errorMessage)
    }

    var body: some View {
        Form {
            if let errorMessage {
                Label {
                    errorMessage
                        .foregroundStyle(.red)
                } icon: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }

            Section {
                HStack {
                    statusLabelView
                    Spacer()
                    statusContentView
                }
            } footer: {
                if licenseState == .notLoggedIn {
                    Text(L10n.licenseCheckIfAlreadyAcquired.key, bundle: .localize)
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                        .tint(.accentColor)
                }
            }

            Section {
                if licenseState != .notLoggedIn {
                    LabeledContent {
                        Button {
                            licenseManager.openManagementPage()
                        } label: {
                            Label {
                                Text(L10n.accountManagement.key, bundle: .localize)
                            } icon: {
                                Image(systemName: "gearshape.fill")
                            }
                        }
                        .buttonStyle(.bordered)
                    } label: {
                        Text(L10n.manageAccountAndSubscription.key, bundle: .localize)
                    }
                }
            } footer: {
                if licenseState != .notLoggedIn {
                    Button {
                        isSignOutAlertPresented = true
                    } label: {
                        Label {
                            Text(L10n.signOut.key, bundle: .localize)
                        } icon: {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                        }
                    }
                    .buttonStyle(.bordered)
                    .listRowBackground(Color.clear)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .formStyle(.grouped)
        .disabled(licenseState == .loading)
        .confirmationDialog(Text(L10n.signOut.key, bundle: .localize), isPresented: $isSignOutAlertPresented) {
            Button(role: .cancel) {
            } label: {
                Text(L10n.cancel.key, bundle: .localize)
            }

            Button(role: .destructive) {
                signOut()
            } label: {
                Text(L10n.signOut.key, bundle: .localize)
            }
        } message: {
            Text(L10n.confirmSignOut.key, bundle: .localize)
        }
    }

    @ViewBuilder
    private var statusLabelView: some View {
        switch licenseState {
        case .loading:
            HStack {
                ProgressView()
                    .controlSize(.small)
                Text(L10n.checkingLicense.key, bundle: .localize)
                    .foregroundStyle(.secondary)
            }

        case .notLoggedIn:
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.commercialLicenseNotActive.key, bundle: .localize)
                        .font(.headline)
                    Text(L10n.commercialLicenseRequired.key, bundle: .localize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
            }

        case .active:
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.commercialLicenseActive.key, bundle: .localize)
                        .font(.headline)
                    if let expiryDate {
                        (Text(L10n.expiryDate.key, bundle: .localize) + Text(expiryDate, style: .date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

        case .inactive:
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.commercialLicenseNotActive.key, bundle: .localize)
                        .font(.headline)
                    Text(L10n.pleaseReauthenticate.key, bundle: .localize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
            }

        case .expired:
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.licenseExpired.key, bundle: .localize)
                        .font(.headline)
                    if let expiryDate {
                        (Text(L10n.expiryDate.key, bundle: .localize) + Text(expiryDate, style: .date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } icon: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var statusContentView: some View {
        switch licenseState {
        case .loading:
            EmptyView()
        case .notLoggedIn:
            Link(destination: licenseManager.licenseURL) {
                Text(L10n.acquireLicense.key, bundle: .localize)
            }
            .buttonStyle(.bordered)
        case .active, .inactive, .expired:
            Button {
                licenseManager.signIn()
            } label: {
                Label {
                    Text(L10n.reauthenticate.key, bundle: .localize)
                } icon: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private func signOut() {
        do {
            try licenseManager.signOut()
            errorMessage = nil
        } catch {
            Logger.error(error)
            errorMessage = Text(L10n.signOutFailed.key, bundle: .localize)
        }
    }
}

// MARK: - Previews

#Preview("Not Logged In") {
    VCamSettingLicenseView()
        .environment(\.licenseManager, LicenseManagerStub(
            licenseState: .notLoggedIn
        ))
        .environment(\.locale, Locale(identifier: "ja_JP"))
}

#Preview("Logged In / Active") {
    VCamSettingLicenseView()
        .environment(\.licenseManager, LicenseManagerStub(
            licenseState: .active,
            expiryDate: Date().addingTimeInterval(30 * 24 * 60 * 60),
        ))
}

#Preview("Logged In / Inactive") {
    VCamSettingLicenseView()
        .environment(\.licenseManager, LicenseManagerStub(
            licenseState: .inactive,
            expiryDate: Date().addingTimeInterval(-10 * 24 * 60 * 60),
        ))
}

#Preview("Expired") {
    VCamSettingLicenseView()
        .environment(\.licenseManager, LicenseManagerStub(
            licenseState: .expired,
            expiryDate: Date().addingTimeInterval(-5 * 24 * 60 * 60),
        ))
}

#Preview("Loading") {
    VCamSettingLicenseView()
        .environment(\.licenseManager, LicenseManagerStub(
            licenseState: .loading
        ))
}

#Preview("Error") {
    VCamSettingLicenseView(
        errorMessage: Text("Network Error")
    )
    .environment(\.licenseManager, LicenseManagerStub(
        licenseState: .inactive
    ))
}
