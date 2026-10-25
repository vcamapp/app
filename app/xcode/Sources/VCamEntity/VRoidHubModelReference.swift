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
