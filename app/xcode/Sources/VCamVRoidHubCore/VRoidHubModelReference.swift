import Foundation
import VRoidSDK

/// Identifies a VRoid Hub model by the version a download license actually
/// granted. Apps persist this instead of the model file: the model itself is
/// re-fetched through the SDK's encrypted cache
public struct VRoidHubModelReference: Codable, Hashable, Sendable {
    public let characterModelID: String
    public let characterModelVersionID: String

    public init(characterModelID: String, characterModelVersionID: String) {
        self.characterModelID = characterModelID
        self.characterModelVersionID = characterModelVersionID
    }
}

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
