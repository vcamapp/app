import Foundation
import VCamData
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
        try await install { (model.data, model.reference) }
    }

    private func install(_ decrypt: () async throws -> (data: Data, reference: VRoidModelReference)) async throws {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let (data, reference) = try await decrypt()
        try await installModel(data, reference)
        VRoidModelReference.lastUsed = reference
    }
}

/// A model the app has downloaded and decrypted into memory
struct DecryptedVRoidModel {
    let data: Data
    let reference: VRoidModelReference
}
