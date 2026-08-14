import Foundation
import VRoidSDK

/// Sign-in state shared by the VRoid Hub window.
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

    let client: VRoidHubClient

    public init?() {
        guard let client = VRoidHub.client else { return nil }
        self.client = client
    }

    public func restoreSession() async {
        phase = .restoringSession
        do {
            if let account = try await client.restoreSession() {
                phase = .signedIn(account)
            } else {
                phase = .signedOut
            }
        } catch {
            // Temporary failures (offline etc.) fall back to the sign-in
            // screen; signing in again recovers
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
