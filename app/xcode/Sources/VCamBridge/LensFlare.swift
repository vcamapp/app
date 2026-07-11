import Foundation

public enum LensFlare: Int32, CaseIterable, Identifiable {
    case none, type1, type2, type3, type4

    public var id: Self { self }

    public static func initOrNone(_ value: Int32) -> Self {
        .init(rawValue: value) ?? .none
    }

}
