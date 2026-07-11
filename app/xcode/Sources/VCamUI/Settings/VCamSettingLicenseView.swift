import SwiftUI
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
                    Text(.licenseCheckIfAlreadyAcquired)
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
                                Text(.accountManagement)
                            } icon: {
                                Image(systemName: "gearshape.fill")
                            }
                        }
                        .buttonStyle(.bordered)
                    } label: {
                        Text(.manageAccountAndSubscription)
                    }
                }
            } footer: {
                if licenseState != .notLoggedIn {
                    Button {
                        isSignOutAlertPresented = true
                    } label: {
                        Label {
                            Text(.signOut)
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
        .confirmationDialog(Text(.signOut), isPresented: $isSignOutAlertPresented) {
            Button(role: .cancel) {
            } label: {
                Text(.cancel)
            }

            Button(role: .destructive) {
                signOut()
            } label: {
                Text(.signOut)
            }
        } message: {
            Text(.confirmSignOut)
        }
    }

    @ViewBuilder
    private var statusLabelView: some View {
        switch licenseState {
        case .loading:
            HStack {
                ProgressView()
                    .controlSize(.small)
                Text(.checkingLicense)
                    .foregroundStyle(.secondary)
            }

        case .notLoggedIn:
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(.commercialLicenseNotActive)
                        .font(.headline)
                    Text(.commercialLicenseRequired)
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
                    Text(.commercialLicenseActive)
                        .font(.headline)
                    if let expiryDate {
                        (Text(.expiryDate) + Text(expiryDate, style: .date))
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
                    Text(.commercialLicenseNotActive)
                        .font(.headline)
                    Text(.pleaseReauthenticate)
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
                    Text(.licenseExpired)
                        .font(.headline)
                    if let expiryDate {
                        (Text(.expiryDate) + Text(expiryDate, style: .date))
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
                Text(.acquireLicense)
            }
            .buttonStyle(.bordered)
        case .active, .inactive, .expired:
            Button {
                licenseManager.signIn()
            } label: {
                Label {
                    Text(.reauthenticate)
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
            errorMessage = Text(.signOutFailed)
        }
    }
}

// MARK: - Previews

#Preview("Not Logged In") {
    VCamSettingLicenseView()
        .environment(\.licenseManager, LicenseManagerStub(
            licenseState: .notLoggedIn
        ))
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
        errorMessage: Text(verbatim: "Network Error")
    )
    .environment(\.licenseManager, LicenseManagerStub(
        licenseState: .inactive
    ))
}
