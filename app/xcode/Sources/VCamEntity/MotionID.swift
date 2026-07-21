import Foundation

public enum MotionID: Hashable, Sendable, RawRepresentable {
    case builtIn(name: String)
    case imported(id: UUID)

    private static let builtInPrefix = "builtin:"
    private static let importedPrefix = "vrma:"

    public init?(rawValue: String) {
        if rawValue.hasPrefix(Self.builtInPrefix) {
            let name = String(rawValue.dropFirst(Self.builtInPrefix.count))
            guard !name.isEmpty else { return nil }
            self = .builtIn(name: name)
        } else if rawValue.hasPrefix(Self.importedPrefix),
                  let id = UUID(uuidString: String(rawValue.dropFirst(Self.importedPrefix.count))) {
            self = .imported(id: id)
        } else {
            return nil
        }
    }

    public var rawValue: String {
        switch self {
        case .builtIn(let name):
            Self.builtInPrefix + name
        case .imported(let id):
            Self.importedPrefix + id.uuidString
        }
    }
}
