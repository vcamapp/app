import Foundation

public enum Avatar {
    public struct Expression: Identifiable, Hashable, Sendable {
        public var name: String

        public var id: String { name }

        public init(name: String) {
            self.name = name
        }
    }

    public struct Motion: Identifiable, Sendable {
        public let id: String
        public var displayName: String

        public init(id: String, displayName: String) {
            self.id = id
            self.displayName = displayName
        }
    }
}

public extension Avatar.Motion {
    static func builtIn(name: String) -> Self {
        .init(id: MotionID.builtIn(name: name).rawValue, displayName: name)
    }

    static func imported(record: ImportedMotionRecord) -> Self {
        .init(id: record.motionID, displayName: record.displayName)
    }
}
