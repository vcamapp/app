import SwiftUI
import VRoidSDK

public struct VRoidHubView: View {
    @State private var session = VRoidHubSession()

    /// Called when a model has been loaded into VCam and the window can close
    private let onFinished: () -> Void

    public init(onFinished: @escaping () -> Void = {}) {
        self.onFinished = onFinished
    }

    public var body: some View {
        Group {
            if let session {
                VRoidHubContentView(session: session, onFinished: onFinished)
                    .task {
                        await session.restoreSession()
                    }
            } else {
                // Only reachable when the credential injection is missing
                ContentUnavailableView {
                    Label {
                        Text(verbatim: "VRoid Hub")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                }
            }
        }
        .frame(minWidth: 760, minHeight: 520)
    }
}

private struct VRoidHubContentView: View {
    let session: VRoidHubSession
    let onFinished: () -> Void

    var body: some View {
        switch session.phase {
        case .restoringSession:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .signedOut, .signingIn:
            VRoidHubSignInView(session: session)
        case .signedIn(let account):
            VRoidHubModelBrowserView(session: session, account: account, onFinished: onFinished)
        }
    }
}

private struct VRoidHubSignInView: View {
    let session: VRoidHubSession

    @State private var signInFailed = false

    private var isSigningIn: Bool {
        if case .signingIn = session.phase { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(.vroidHubSignInDescription)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button {
                signIn()
            } label: {
                if isSigningIn {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(.signInToVRoidHub)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSigningIn)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert(.signInFailed, isPresented: $signInFailed) {}
    }

    private func signIn() {
        Task {
            do {
                try await session.signIn()
            } catch VRoidHubError.authenticationCancelled {
                // Closing the browser is not an error
            } catch {
                signInFailed = true
            }
        }
    }
}
