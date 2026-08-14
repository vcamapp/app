import Foundation
import VCamDefaults

/// Identifies a VRoid Hub model without keeping the model file itself.
///
/// The plaintext VRM of a VRoid Hub model is never persisted; only this
/// reference survives a restart, and the model is fetched again through the
/// SDK's encrypted cache when restoring.
public struct VRoidModelReference: Codable, Sendable, Equatable {
    public let characterModelID: String
    public let characterModelVersionID: String

    public init(characterModelID: String, characterModelVersionID: String) {
        self.characterModelID = characterModelID
        self.characterModelVersionID = characterModelVersionID
    }
}

extension VRoidModelReference: UserDefaultsJSONValue {}

public extension VRoidModelReference {
    /// The VRoid Hub model currently in use, or nil when the last loaded
    /// avatar came from anywhere else
    static var lastUsed: VRoidModelReference? {
        get { UserDefaults.standard.value(for: .lastVRoidModel) }
        set { UserDefaults.standard.set(newValue, for: .lastVRoidModel) }
    }
}

public extension UserDefaults.Key {
    static var lastVRoidModel: UserDefaults.Key<VRoidModelReference?> { .init("vc_last_vroid_model", default: nil) }
}
