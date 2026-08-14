import Foundation
import VCamData
import VCamLogger
import VRoidSDK

/// Entry point of the VRoid Hub integration.
///
/// The API credential and the model install pipeline are injected at startup
/// from outside the open source modules; until then the feature is
/// unavailable and the UI entry points should be hidden.
@MainActor
public enum VRoidHub {
    /// Loads decrypted model data into the running app
    public typealias ModelInstaller = (_ data: Data, _ reference: VRoidModelReference) async throws -> Void

    private struct Integration {
        let credential: VRoidCredential
        let installModel: ModelInstaller
    }

    private static var integration: Integration?
    private static var sharedClient: VRoidHubClient?
    private static var sharedModelLoader: VRoidHubModelLoader?

    public static var isAvailable: Bool { integration != nil }

    public static func configure(clientID: String, clientSecret: String, installModel: @escaping ModelInstaller) {
        integration = Integration(
            credential: VRoidCredential(clientID: clientID, clientSecret: clientSecret),
            installModel: installModel
        )
    }

    /// The single client of the app: the SDK coalesces concurrent downloads and
    /// token refreshes per instance, so browsing and restoring must share one
    static var client: VRoidHubClient? {
        guard let integration else { return nil }
        if let sharedClient { return sharedClient }
        let client = VRoidHubClient(configuration: VRoidHubConfiguration(
            credential: integration.credential,
            // The URI registered on the VRoid Hub application settings page;
            // the SDK rewrites the port at runtime
            callback: .loopbackServer(redirectURI: URL(string: "http://127.0.0.1")!)
        ))
        sharedClient = client
        return client
    }

    /// Shared so that a launch restore and a user's selection never install at once
    static var modelLoader: VRoidHubModelLoader? {
        guard let integration, let client else { return nil }
        if let sharedModelLoader { return sharedModelLoader }
        let loader = VRoidHubModelLoader(client: client, installModel: integration.installModel)
        sharedModelLoader = loader
        return loader
    }

    private static var didAttemptRestore = false

    /// Reloads the last used VRoid Hub model through the SDK's encrypted cache.
    ///
    /// The engine restores the last file-based model (or the sample) on its own, so
    /// this quietly replaces it afterwards and gives up on any failure —
    /// signing in again or reselecting the model recovers.
    public static func restoreLastModelOnLaunch() {
        guard !didAttemptRestore else { return }
        didAttemptRestore = true

        guard let client, let modelLoader, let reference = VRoidModelReference.lastUsed else { return }

        Task {
            do {
                guard try await client.restoreSession() != nil else { return }
                try await modelLoader.useModel(StoredModelReference(reference: reference))
                Logger.log("Restored the last VRoid Hub model")
            } catch {
                Logger.log("VRoid Hub model restoration failed: \(error)")
            }
        }
    }
}

/// Feeds the persisted IDs back to the SDK so a cached model with a valid
/// license loads without any network access
private struct StoredModelReference: VRoidCharacterModelDownloadable {
    let reference: VRoidModelReference

    var characterModelID: String { reference.characterModelID }
    var latestVersionID: String? { reference.characterModelVersionID }
}

extension VRoidHubClient {
    /// Downloads and decrypts a model, along with the reference of the version
    /// the download license actually granted
    func decryptedModel(_ model: some VRoidCharacterModelDownloadable) async throws -> (data: Data, reference: VRoidModelReference) {
        let downloaded = try await downloadModel(model)
        let data = try await modelData(for: downloaded)
        let reference = VRoidModelReference(
            characterModelID: downloaded.characterModelID,
            characterModelVersionID: downloaded.characterModelVersionID
        )
        return (data, reference)
    }
}
