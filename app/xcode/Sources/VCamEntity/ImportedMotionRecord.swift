import Foundation

public struct ImportedMotionRecord: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var displayName: String
    public var translationAxes: TranslationAxisMask
    public var isLoop: Bool
    /// A still pose rather than a motion: the head, hands and fingers keep following tracking on top of it
    public var isPose: Bool

    public init(
        id: UUID = UUID(),
        displayName: String,
        translationAxes: TranslationAxisMask = .all,
        isLoop: Bool = false,
        isPose: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.translationAxes = translationAxes
        self.isLoop = isLoop
        self.isPose = isPose
    }

    public var motionID: String {
        MotionID.imported(id: id).rawValue
    }
}

public extension ImportedMotionRecord {
    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case translationAxes
        case isLoop
        case isPose
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        translationAxes = try container.decode(TranslationAxisMask.self, forKey: .translationAxes)
        isLoop = try container.decodeIfPresent(Bool.self, forKey: .isLoop) ?? false
        isPose = try container.decodeIfPresent(Bool.self, forKey: .isPose) ?? false
    }
}
