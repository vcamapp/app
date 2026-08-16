import Foundation

public struct VCamSubtitleActionConfiguration: VCamActionConfiguration {
    public init(id: UUID = UUID(), text: String = "") {
        self.id = id
        self.text = text
    }

    public var id = UUID()
    public var text: String = ""

    // Saved shortcuts still carry the key this action had when it was called a message
    private enum CodingKeys: String, CodingKey {
        case id
        case text = "message"
    }

    public static var `default`: Self { .init() }

    public func erased() -> AnyVCamActionConfiguration {
        .message(configuration: self)
    }
}
