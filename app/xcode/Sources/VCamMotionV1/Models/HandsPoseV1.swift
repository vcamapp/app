@available(iOS 26.0, macOS 26.0, *)
public struct HandsPoseV1: Sendable {
    public var left: HandPoseV1
    public var right: HandPoseV1

    public init(left: HandPoseV1 = .init(), right: HandPoseV1 = .init()) {
        self.left = left
        self.right = right
    }
}
