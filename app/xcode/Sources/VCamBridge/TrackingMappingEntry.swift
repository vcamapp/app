import Foundation
import simd

public struct TrackingMappingEntry: Codable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public var isEnabled: Bool
    public var input: InputKey
    public var outputKey: OutputKey
    public var filter: TrackingFilter

    public init(id: UUID = UUID(), isEnabled: Bool = true, input: InputKey, outputKey: OutputKey, filter: TrackingFilter = .none) {
        self.id = id
        self.isEnabled = isEnabled
        self.input = input
        self.outputKey = outputKey
        self.filter = filter
    }

    public func scaleValue(_ value: Float) -> Float {
        guard input.rangeMax != input.rangeMin else { return 0 }
        let lowerBound = Swift.min(input.rangeMin, input.rangeMax)
        let upperBound = Swift.max(input.rangeMin, input.rangeMax)
        let clamped = simd_clamp(value, lowerBound, upperBound)
        return (clamped - input.rangeMin) / (input.rangeMax - input.rangeMin) * 2 - 1
    }

    public mutating func resetToDefault(for mode: TrackingMode) {
        input.resetToDefault(for: mode)
        outputKey.resetToDefault(for: mode)
        filter = .none
    }

    public func bounds(for side: Side) -> ClosedRange<Float> {
        switch side {
        case .input: input.bounds
        case .output: outputKey.bounds
        }
    }

    /// Reverses the mapping direction by swapping the range of the given side
    public mutating func reverseDirection(_ side: Side) {
        switch side {
        case .input: swap(&input.rangeMin, &input.rangeMax)
        case .output: swap(&outputKey.rangeMin, &outputKey.rangeMax)
        }
    }

    public mutating func updateBounds(_ bounds: ClosedRange<Float>, for side: Side) {
        switch side {
        case .input: input.updateBounds(bounds)
        case .output: outputKey.updateBounds(bounds)
        }
    }
}

/// Mapping entries kept per tracking mode
public struct TrackingMappings: Equatable, Sendable {
    public var blendShape: [TrackingMappingEntry]
    /// Filled in once the avatar turns out to support Perfect Sync
    public var perfectSync: [TrackingMappingEntry]

    public init(blendShape: [TrackingMappingEntry] = TrackingMappingEntry.defaultMappings(for: .blendShape),
                perfectSync: [TrackingMappingEntry] = []) {
        self.blendShape = blendShape
        self.perfectSync = perfectSync
    }

    public subscript(mode: TrackingMode) -> [TrackingMappingEntry] {
        get {
            switch mode {
            case .blendShape: blendShape
            case .perfectSync: perfectSync
            }
        }
        set {
            switch mode {
            case .blendShape: blendShape = newValue
            case .perfectSync: perfectSync = newValue
            }
        }
    }
}

public extension TrackingMappingEntry {
    /// The side of a mapping an operation applies to
    enum Side: Sendable, Hashable {
        case input
        case output
    }

    protocol Key: Identifiable, Sendable, Hashable, Codable {
        var key: String { get }
        var bounds: ClosedRange<Float> { get set }
        var rangeMin: Float { get set }
        var rangeMax: Float { get set }

        init(key: String, bounds: ClosedRange<Float>?, rangeMin: Float?, rangeMax: Float?)
    }

    struct InputKey: Key {
        public var key: String
        public var bounds: ClosedRange<Float>
        public var rangeMin: Float
        public var rangeMax: Float

        public init(key: String, bounds: ClosedRange<Float>?, rangeMin: Float? = nil, rangeMax: Float? = nil) {
            self.key = key
            self.bounds = bounds ?? DefaultMappingDefinition.allKeys.first { $0.key == key }?.bounds ?? -1...1
            self.rangeMin = rangeMin ?? self.bounds.lowerBound
            self.rangeMax = rangeMax ?? self.bounds.upperBound
        }

        public mutating func resetToDefault(for mode: TrackingMode) {
            guard let definition = TrackingMappingEntry.defaultMappingDefinition(for: key, mode: mode) else { return }
            bounds = definition.inputKey.bounds
            rangeMin = definition.inputKey.rangeMin
            rangeMax = definition.inputKey.rangeMax
        }
    }

    struct OutputKey: Key {
        public var key: String
        public var bounds: ClosedRange<Float>
        public var rangeMin: Float
        public var rangeMax: Float

        public static let empty = OutputKey(key: "", bounds: -1...1)

        public init(key: String, bounds: ClosedRange<Float>? = nil, rangeMin: Float? = nil, rangeMax: Float? = nil) {
            self.key = key
            self.bounds = bounds ?? DefaultMappingDefinition.allKeys.first { $0.key == key }?.bounds ?? -1...1
            self.rangeMin = rangeMin ?? self.bounds.lowerBound
            self.rangeMax = rangeMax ?? self.bounds.upperBound
        }

        public mutating func resetToDefault(for mode: TrackingMode) {
            guard let defaultKey = TrackingMappingEntry.defaultOutputKey(for: key, mode: mode) else { return }
            self = defaultKey
        }
    }


    struct DefaultMappingDefinition: Sendable, Hashable {
        public let inputKey: InputKey
        public let outputKey: OutputKey
        public let filter: TrackingFilter

        public var key: String { inputKey.key }
        public var bounds: ClosedRange<Float> { inputKey.bounds }

        public init(
            key: String,
            bounds: ClosedRange<Float>,
            rangeMin: Float? = nil,
            rangeMax: Float? = nil,
            outputRangeMin: Float? = nil,
            outputRangeMax: Float? = nil,
            filter: TrackingFilter = .none
        ) {
            self.inputKey = InputKey(key: key, bounds: bounds, rangeMin: rangeMin, rangeMax: rangeMax)
            self.outputKey = OutputKey(key: key, bounds: bounds, rangeMin: outputRangeMin, rangeMax: outputRangeMax)
            self.filter = filter
        }
    }
}

public extension TrackingMappingEntry.Key {
    var id: String { key }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: RangeKeyCodingKeys.self)
        let key = try container.decode(String.self, forKey: .key)
        let boundsMin = try container.decode(Float.self, forKey: .boundsMin)
        let boundsMax = try container.decode(Float.self, forKey: .boundsMax)
        let rangeMin = try container.decode(Float.self, forKey: .rangeMin)
        let rangeMax = try container.decode(Float.self, forKey: .rangeMax)
        self.init(key: key, bounds: boundsMin...boundsMax, rangeMin: rangeMin, rangeMax: rangeMax)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: RangeKeyCodingKeys.self)
        try container.encode(key, forKey: .key)
        try container.encode(bounds.lowerBound, forKey: .boundsMin)
        try container.encode(bounds.upperBound, forKey: .boundsMax)
        try container.encode(rangeMin, forKey: .rangeMin)
        try container.encode(rangeMax, forKey: .rangeMax)
    }

    /// Applies new bounds, keeping the current range inside them
    mutating func updateBounds(_ newBounds: ClosedRange<Float>) {
        let wasReversed = rangeMin > rangeMax
        let wasCollapsed = rangeMin == rangeMax
        bounds = newBounds
        rangeMin = simd_clamp(rangeMin, newBounds.lowerBound, newBounds.upperBound)
        rangeMax = simd_clamp(rangeMax, newBounds.lowerBound, newBounds.upperBound)
        if rangeMin == rangeMax, !wasCollapsed {
            if wasReversed {
                rangeMin = newBounds.upperBound
                rangeMax = newBounds.lowerBound
            } else {
                rangeMin = newBounds.lowerBound
                rangeMax = newBounds.upperBound
            }
        }
    }
}

private enum RangeKeyCodingKeys: String, CodingKey {
    case key, boundsMin, boundsMax, rangeMin, rangeMax
}

public extension TrackingMappingEntry.DefaultMappingDefinition {
    static let posX = Self(key: "_posX", bounds: -1...1)
    static let posY = Self(key: "_posY", bounds: -1...1, outputRangeMin: 0, outputRangeMax: 0)
    static let posZ = Self(key: "_posZ", bounds: -1...1, outputRangeMin: 0, outputRangeMax: 0)
    static let headX = Self(key: "_headX", bounds: -90...90)
    static let headY = Self(key: "_headY", bounds: -90...90)
    static let headZ = Self(key: "_headZ", bounds: -90...90)
    static let eyeX = Self(key: "_eyeX", bounds: -1...1, rangeMin: -0.6, rangeMax: 0.6, filter: .oneEuro(minCutoff: 1.0, beta: 0.8))
    static let eyeY = Self(key: "_eyeY", bounds: -1...1, rangeMin: -0.2, rangeMax: 0.2, filter: .oneEuro(minCutoff: 1.0, beta: 0.2))
    static let blinkL = Self(key: "_blinkL", bounds: 0...1, rangeMin: 0.2, rangeMax: 0.8, filter: .oneEuro(minCutoff: 0.3, beta: 1.0))
    static let blinkR = Self(key: "_blinkR", bounds: 0...1, rangeMin: 0.2, rangeMax: 0.8, filter: .oneEuro(minCutoff: 0.3, beta: 1.0))
    static let mouth = Self(key: "_mouth", bounds: 0...1)
    static let iPhonePosZ = Self(key: "_posZ", bounds: -1...1, rangeMin: -1, rangeMax: 0, outputRangeMin: 0, outputRangeMax: 0)
    static let iPhoneEyeX = Self(key: "_eyeX", bounds: -1...1)
    static let iPhoneEyeY = Self(key: "_eyeY", bounds: -1...1)
    static let iPhoneBlinkL = Self(key: "_blinkL", bounds: 0...1)
    static let iPhoneBlinkR = Self(key: "_blinkR", bounds: 0...1)

    // Perfect Sync BlendShapes
    static let browDownLeft = Self(key: "BrowDownLeft", bounds: 0...1)
    static let browDownRight = Self(key: "BrowDownRight", bounds: 0...1)
    static let browInnerUp = Self(key: "BrowInnerUp", bounds: 0...1)
    static let browOuterUpLeft = Self(key: "BrowOuterUpLeft", bounds: 0...1)
    static let browOuterUpRight = Self(key: "BrowOuterUpRight", bounds: 0...1)
    static let cheekPuff = Self(key: "CheekPuff", bounds: 0...1)
    static let cheekSquintLeft = Self(key: "CheekSquintLeft", bounds: 0...1)
    static let cheekSquintRight = Self(key: "CheekSquintRight", bounds: 0...1)
    static let eyeBlinkLeft = Self(key: "EyeBlinkLeft", bounds: 0...1)
    static let eyeBlinkRight = Self(key: "EyeBlinkRight", bounds: 0...1)
    static let eyeLookDownLeft = Self(key: "EyeLookDownLeft", bounds: 0...1)
    static let eyeLookDownRight = Self(key: "EyeLookDownRight", bounds: 0...1)
    static let eyeLookInLeft = Self(key: "EyeLookInLeft", bounds: 0...1)
    static let eyeLookInRight = Self(key: "EyeLookInRight", bounds: 0...1)
    static let eyeLookOutLeft = Self(key: "EyeLookOutLeft", bounds: 0...1)
    static let eyeLookOutRight = Self(key: "EyeLookOutRight", bounds: 0...1)
    static let eyeLookUpLeft = Self(key: "EyeLookUpLeft", bounds: 0...1)
    static let eyeLookUpRight = Self(key: "EyeLookUpRight", bounds: 0...1)
    static let eyeSquintLeft = Self(key: "EyeSquintLeft", bounds: 0...1)
    static let eyeSquintRight = Self(key: "EyeSquintRight", bounds: 0...1)
    static let eyeWideLeft = Self(key: "EyeWideLeft", bounds: 0...1)
    static let eyeWideRight = Self(key: "EyeWideRight", bounds: 0...1)
    static let jawForward = Self(key: "JawForward", bounds: 0...1)
    static let jawLeft = Self(key: "JawLeft", bounds: 0...1)
    static let jawOpen = Self(key: "JawOpen", bounds: 0...1)
    static let jawRight = Self(key: "JawRight", bounds: 0...1)
    static let mouthClose = Self(key: "MouthClose", bounds: 0...1)
    static let mouthDimpleLeft = Self(key: "MouthDimpleLeft", bounds: 0...1)
    static let mouthDimpleRight = Self(key: "MouthDimpleRight", bounds: 0...1)
    static let mouthFrownLeft = Self(key: "MouthFrownLeft", bounds: 0...1)
    static let mouthFrownRight = Self(key: "MouthFrownRight", bounds: 0...1)
    static let mouthFunnel = Self(key: "MouthFunnel", bounds: 0...1)
    static let mouthLeft = Self(key: "MouthLeft", bounds: 0...1)
    static let mouthLowerDownLeft = Self(key: "MouthLowerDownLeft", bounds: 0...1)
    static let mouthLowerDownRight = Self(key: "MouthLowerDownRight", bounds: 0...1)
    static let mouthPressLeft = Self(key: "MouthPressLeft", bounds: 0...1)
    static let mouthPressRight = Self(key: "MouthPressRight", bounds: 0...1)
    static let mouthPucker = Self(key: "MouthPucker", bounds: 0...1)
    static let mouthRight = Self(key: "MouthRight", bounds: 0...1)
    static let mouthRollLower = Self(key: "MouthRollLower", bounds: 0...1)
    static let mouthRollUpper = Self(key: "MouthRollUpper", bounds: 0...1)
    static let mouthShrugLower = Self(key: "MouthShrugLower", bounds: 0...1)
    static let mouthShrugUpper = Self(key: "MouthShrugUpper", bounds: 0...1)
    static let mouthSmileLeft = Self(key: "MouthSmileLeft", bounds: 0...1)
    static let mouthSmileRight = Self(key: "MouthSmileRight", bounds: 0...1)
    static let mouthStretchLeft = Self(key: "MouthStretchLeft", bounds: 0...1)
    static let mouthStretchRight = Self(key: "MouthStretchRight", bounds: 0...1)
    static let mouthUpperUpLeft = Self(key: "MouthUpperUpLeft", bounds: 0...1)
    static let mouthUpperUpRight = Self(key: "MouthUpperUpRight", bounds: 0...1)
    static let noseSneerLeft = Self(key: "NoseSneerLeft", bounds: 0...1)
    static let noseSneerRight = Self(key: "NoseSneerRight", bounds: 0...1)
    static let tongueOut = Self(key: "TongueOut", bounds: 0...1)

    static let perfectSyncFacialDefinitions: [Self] = [
        .browDownLeft, .browDownRight, .browInnerUp, .browOuterUpLeft, .browOuterUpRight,
        .cheekPuff, .cheekSquintLeft, .cheekSquintRight,
        .eyeBlinkLeft, .eyeBlinkRight,
        .eyeLookDownLeft, .eyeLookDownRight, .eyeLookInLeft, .eyeLookInRight,
        .eyeLookOutLeft, .eyeLookOutRight, .eyeLookUpLeft, .eyeLookUpRight,
        .eyeSquintLeft, .eyeSquintRight, .eyeWideLeft, .eyeWideRight,
        .jawForward, .jawLeft, .jawOpen, .jawRight,
        .mouthClose, .mouthDimpleLeft, .mouthDimpleRight,
        .mouthFrownLeft, .mouthFrownRight, .mouthFunnel, .mouthLeft,
        .mouthLowerDownLeft, .mouthLowerDownRight,
        .mouthPressLeft, .mouthPressRight, .mouthPucker, .mouthRight,
        .mouthRollLower, .mouthRollUpper, .mouthShrugLower, .mouthShrugUpper,
        .mouthSmileLeft, .mouthSmileRight, .mouthStretchLeft, .mouthStretchRight,
        .mouthUpperUpLeft, .mouthUpperUpRight,
        .noseSneerLeft, .noseSneerRight, .tongueOut,
    ]

    static let allKeys: [Self] = [
        .posX, .posY, .posZ,
        .headX, .headY, .headZ,
        .eyeX, .eyeY,
        .blinkL, .blinkR,
        .mouth,
    ] + perfectSyncFacialDefinitions
}

public extension TrackingMappingEntry {
    private static func mappingDefinitions(for mode: TrackingMode) -> [DefaultMappingDefinition] {
        switch mode {
        case .perfectSync:
            return perfectSyncMappingDefinitions
        case .blendShape:
            return blendShapeMappingDefinitions
        }
    }

#if FEATURE_3
    private static let perfectSyncMappingDefinitions: [DefaultMappingDefinition] = [
        .posX, .posY, .iPhonePosZ,
        .headX, .headY, .headZ,
        .iPhoneEyeX, .iPhoneEyeY,
    ] + DefaultMappingDefinition.perfectSyncFacialDefinitions
#else
    private static let perfectSyncMappingDefinitions: [DefaultMappingDefinition] = [
        .posX, .posY, .iPhonePosZ,
        .headX, .headY, .headZ,
        .iPhoneBlinkL, .iPhoneBlinkR,
        .mouth,
        .iPhoneEyeX, .iPhoneEyeY
    ]
#endif

    private static let blendShapeMappingDefinitions: [DefaultMappingDefinition] = [
        .posX, .posY, .posZ,
        .headX, .headY, .headZ,
        .blinkL, .blinkR,
        .mouth,
        .eyeX, .eyeY
    ]

    private static let perfectSyncInputKeys = perfectSyncMappingDefinitions.map(\.inputKey)
    private static let blendShapeInputKeys = blendShapeMappingDefinitions.map(\.inputKey)

    static func availableInputKeys(for mode: TrackingMode) -> [InputKey] {
        switch mode {
        case .perfectSync:
            perfectSyncInputKeys
        case .blendShape:
            blendShapeInputKeys
        }
    }

    static func defaultMappingDefinition(for key: String, mode: TrackingMode) -> DefaultMappingDefinition? {
        mappingDefinitions(for: mode).first { $0.key == key }
    }

    static func defaultOutputKey(for key: String, mode: TrackingMode) -> OutputKey? {
        defaultMappingDefinition(for: key, mode: mode)?.outputKey
    }

    static func defaultMappings(for mode: TrackingMode) -> [TrackingMappingEntry] {
        mappingDefinitions(for: mode)
            .map {
                TrackingMappingEntry(
                    input: $0.inputKey,
                    outputKey: $0.outputKey,
                    filter: $0.filter
                )
            }
    }
}
