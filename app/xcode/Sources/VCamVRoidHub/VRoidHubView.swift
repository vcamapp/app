import SwiftUI
import VCamVRoidHubCore

public struct VRoidHubView: View {
    // Only nil when the credential injection is missing
    @State private var session = VRoidHub.client.map { VRoidHubSession(client: $0) }

    /// Called when a model has been loaded into VCam and the window can close
    private let onFinished: () -> Void

    public init(onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
    }

    public var body: some View {
        Group {
            if let session {
                VRoidHubContentView(session: session, onFinished: onFinished)
                    .task {
                        await session.restoreSessionIfNeeded()
                    }
            } else {
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
