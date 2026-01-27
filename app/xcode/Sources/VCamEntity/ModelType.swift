public enum ModelType: String, Codable, Hashable, Sendable {
#if FEATURE_3
    case vrm
#else
    case live2d
#endif

    public var displayName: String {
        switch self {
#if FEATURE_3
        case .vrm: return "VRM"
#else
        case .live2d: return "Live2D"
#endif
        }
    }
}
