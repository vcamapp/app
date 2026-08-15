import Foundation

public struct VCamColor: Codable, Equatable, Hashable, Sendable {
    public init(red: Float, green: Float, blue: Float, alpha: Float = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public var red: Float
    public var green: Float
    public var blue: Float
    public var alpha: Float
}

public extension VCamColor {
    static let green = VCamColor(red: 0, green: 1, blue: 0, alpha: 1)
    static let white = VCamColor(red: 1, green: 1, blue: 1, alpha: 1)
    static let black = VCamColor(red: 0, green: 0, blue: 0, alpha: 1)
}
