import Foundation
import VRoidSDK

/// Sign-in state shared by the VRoid Hub screens.
@MainActor
@Observable
public final class VRoidHubSession {
    public enum Phase {
        case restoringSession
        case signedOut
        case signingIn
        case signedIn(VRoidAccount)
    }

    public private(set) var phase: Phase = .restoringSession

    public let client: VRoidHubClient

    public init(client: VRoidHubClient) {
        self.client = client
    }

    /// Verifies the stored session over the network unless already signed in.
    /// An expired token then surfaces as a failed list load, and signing in
    /// again recovers
    public func restoreSessionIfNeeded() async {
        if case .signedIn = phase { return }
        do {
            if let account = try await client.restoreSession() {
                phase = .signedIn(account)
            } else {
                phase = .signedOut
            }
        } catch {
            // Temporary failures (offline etc.) fall back to the sign-in screen
            phase = .signedOut
        }
    }

    public func signIn() async throws {
        phase = .signingIn
        do {
            phase = .signedIn(try await client.signIn())
        } catch {
            phase = .signedOut
            throw error
        }
    }

    public func signOut() async {
        try? await client.signOut()
        phase = .signedOut
    }
}
