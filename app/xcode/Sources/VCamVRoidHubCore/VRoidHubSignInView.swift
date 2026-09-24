import SwiftUI
import VRoidSDK

public struct VRoidHubSignInView: View {
    let session: VRoidHubSession

    @State private var signInFailed = false

    public init(session: VRoidHubSession) {
        self.session = session
    }

    private var isSigningIn: Bool {
        if case .signingIn = session.phase { return true }
        return false
    }

    public var body: some View {
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
            .accessibilityIdentifier("vroid_hub_sign_in")
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert(Text(.signInFailed), isPresented: $signInFailed) {}
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
