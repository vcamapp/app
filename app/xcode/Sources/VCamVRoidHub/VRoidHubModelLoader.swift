import Foundation
import VCamData
import VCamVRoidHubCore
import VRoidSDK

/// Downloads a VRoid Hub model and hands the decrypted data to the privately
/// injected installer, which loads it into the running app
@MainActor
@Observable
final class VRoidHubModelLoader {
    private(set) var isLoading = false

    private let client: VRoidHubClient
    private let installModel: VRoidHub.ModelInstaller

    init(client: VRoidHubClient, installModel: @escaping VRoidHub.ModelInstaller) {
        self.client = client
        self.installModel = installModel
    }

    func useModel(_ model: some VRoidCharacterModelDownloadable) async throws {
        try await install { try await client.decryptedModel(model) }
    }

    /// Uses the data the 3D preview already decrypted, avoiding a second decrypt
    func useModel(preloaded model: DecryptedVRoidModel) async throws {
        try await install { model }
    }

    private func install(_ decrypt: () async throws -> DecryptedVRoidModel) async throws {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let model = try await decrypt()
        try await installModel(model.data)
        VRoidModelReference.lastUsed = VRoidModelReference(model.reference)
    }
}
