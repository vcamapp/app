import Foundation
import VCamEntity
import VRoidSDK

/// Feeds a persisted reference back to the SDK so a cached model with a
/// valid license loads without any network access
extension VRoidHubModelReference: VRoidCharacterModelDownloadable {
    public var latestVersionID: String? { characterModelVersionID }
}

public struct DecryptedVRoidModel: Sendable {
    public let reference: VRoidHubModelReference
    public let data: Data

    public init(reference: VRoidHubModelReference, data: Data) {
        self.reference = reference
        self.data = data
    }
}

extension VRoidHubClient {
    /// Downloads and decrypts a model, along with the reference of the version
    /// the download license actually granted. The plaintext never touches disk
    public func decryptedModel(_ model: some VRoidCharacterModelDownloadable) async throws -> DecryptedVRoidModel {
        let downloaded = try await downloadModel(model)
        let data = try await modelData(for: downloaded)
        let reference = VRoidHubModelReference(
            characterModelID: downloaded.characterModelID,
            characterModelVersionID: downloaded.characterModelVersionID
        )
        return DecryptedVRoidModel(reference: reference, data: data)
    }
}
