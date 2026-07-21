import Foundation

public struct VCamMotionActionConfiguration: VCamActionConfiguration {
    public var id = UUID()
    public var motionID: String = MotionID.builtIn(name: "hi").rawValue

    public static var `default`: Self { .init() }

    public func erased() -> AnyVCamActionConfiguration {
        .motion(configuration: self)
    }
}

public extension VCamMotionActionConfiguration {
    private enum CodingKeys: String, CodingKey {
        case id
        case motionID
        case motion // Legacy format (VCamAvatarMotion)
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        if let motionID = try container.decodeIfPresent(String.self, forKey: .motionID) {
            self.motionID = motionID
        } else if let legacyMotion = try container.decodeIfPresent(VCamAvatarMotion.self, forKey: .motion) {
            motionID = MotionID.builtIn(name: legacyMotion.rawValue).rawValue
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(motionID, forKey: .motionID)
    }
}
