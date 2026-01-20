//
//  TrackingMappingEntry.swift
//  
//
//  Created by Tatsuya Tanaka on 2026/01/16.
//

import Foundation
import SwiftUI
import VCamLocalization

public struct TrackingMappingEntry: Codable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public var isEnabled: Bool
    public var input: InputKey
    public var outputKey: OutputKey

    public init(id: UUID = UUID(), isEnabled: Bool = true, input: InputKey, outputKey: OutputKey) {
        self.id = id
        self.isEnabled = isEnabled
        self.input = input
        self.outputKey = outputKey
    }

    public func scaleValue(_ value: Float) -> Float {
        guard input.rangeMax != input.rangeMin else { return 0 }
        let clamped = Swift.min(Swift.max(value, input.rangeMin), input.rangeMax)
        return (clamped - input.rangeMin) / (input.rangeMax - input.rangeMin) * 2 - 1
    }

    public mutating func resetToDefault() {
        input.resetToDefault()
        outputKey.resetToDefault()
    }
}

public extension TrackingMappingEntry {
    protocol Key: Identifiable, Sendable, Hashable, Codable {
        var key: String { get }
    }

    struct InputKey: Key {
        public var key: String
        public var bounds: ClosedRange<Float>
        public var rangeMin: Float
        public var rangeMax: Float

        public init(key: String, bounds: ClosedRange<Float>?, rangeMin: Float? = nil, rangeMax: Float? = nil) {
            self.key = key
            self.bounds = bounds ?? Self.allKeys.first { $0.key == key }?.bounds ?? -1...1
            self.rangeMin = rangeMin ?? self.bounds.lowerBound
            self.rangeMax = rangeMax ?? self.bounds.upperBound
        }

        public mutating func resetToDefault() {
            guard let defaultKey = Self.allKeys.first(where: { $0.key == key }) else { return }
            bounds = defaultKey.bounds
            rangeMin = defaultKey.bounds.lowerBound
            rangeMax = defaultKey.bounds.upperBound
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
            self.bounds = bounds ?? InputKey.allKeys.first { $0.key == key }?.bounds ?? -1...1
            self.rangeMin = rangeMin ?? self.bounds.lowerBound
            self.rangeMax = rangeMax ?? self.bounds.upperBound
        }

        public mutating func resetToDefault() {
            let defaultBounds = InputKey.allKeys.first { $0.key == key }?.bounds ?? -1...1
            bounds = defaultBounds
            rangeMin = defaultBounds.lowerBound
            rangeMax = defaultBounds.upperBound
        }
    }
}

public extension TrackingMappingEntry.Key {
    var isVCamKey: Bool { key.hasPrefix("_") }
    var id: String { key }
    var nameKey: LocalizedStringKey {
        if isVCamKey {
            L10n.key("trackingInput_\(key)").key
        } else {
            "\(key)"
        }
    }
}

extension TrackingMappingEntry.InputKey: Codable {
    private enum CodingKeys: String, CodingKey {
        case key, boundsMin, boundsMax, rangeMin, rangeMax
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let key = try container.decode(String.self, forKey: .key)
        let boundsMin = try container.decode(Float.self, forKey: .boundsMin)
        let boundsMax = try container.decode(Float.self, forKey: .boundsMax)
        let rangeMin = try container.decode(Float.self, forKey: .rangeMin)
        let rangeMax = try container.decode(Float.self, forKey: .rangeMax)
        self.init(key: key, bounds: boundsMin...boundsMax, rangeMin: rangeMin, rangeMax: rangeMax)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(key, forKey: .key)
        try container.encode(bounds.lowerBound, forKey: .boundsMin)
        try container.encode(bounds.upperBound, forKey: .boundsMax)
        try container.encode(rangeMin, forKey: .rangeMin)
        try container.encode(rangeMax, forKey: .rangeMax)
    }
}

extension TrackingMappingEntry.OutputKey: Codable {
    private enum CodingKeys: String, CodingKey {
        case key, boundsMin, boundsMax, rangeMin, rangeMax
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let key = try container.decode(String.self, forKey: .key)
        let boundsMin = try container.decode(Float.self, forKey: .boundsMin)
        let boundsMax = try container.decode(Float.self, forKey: .boundsMax)
        let rangeMin = try container.decode(Float.self, forKey: .rangeMin)
        let rangeMax = try container.decode(Float.self, forKey: .rangeMax)
        self.init(key: key, bounds: boundsMin...boundsMax, rangeMin: rangeMin, rangeMax: rangeMax)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(key, forKey: .key)
        try container.encode(bounds.lowerBound, forKey: .boundsMin)
        try container.encode(bounds.upperBound, forKey: .boundsMax)
        try container.encode(rangeMin, forKey: .rangeMin)
        try container.encode(rangeMax, forKey: .rangeMax)
    }
}

public extension TrackingMappingEntry.InputKey {
    static let posX = Self(key: "_posX", bounds: -1...1)
    static let posY = Self(key: "_posY", bounds: -1...1)
    static let posZ = Self(key: "_posZ", bounds: -1...1)
    static let headX = Self(key: "_headX", bounds: -90...90)
    static let headY = Self(key: "_headY", bounds: -90...90)
    static let headZ = Self(key: "_headZ", bounds: -90...90)
    static let eyeX = Self(key: "_eyeX", bounds: -1...1)
    static let eyeY = Self(key: "_eyeY", bounds: -1...1)
    static let blinkL = Self(key: "_blinkL", bounds: 0...1, rangeMin: 0.02, rangeMax: 0.98)
    static let blinkR = Self(key: "_blinkR", bounds: 0...1, rangeMin: 0.02, rangeMax: 0.98)
    static let mouth = Self(key: "_mouth", bounds: 0...1)

    // ARKit BlendShapes
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

    static let allKeys: Set<Self> = [
        .posX, .posY, .posZ,
        .headX, .headY, .headZ,
        .eyeX, .eyeY,
        .blinkL, .blinkR,
        .mouth,
        // ARKit BlendShapes
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
}

public extension TrackingMappingEntry {
    private static func inputKeyDefinitions(for mode: TrackingMode) -> [InputKey] {
#if FEATURE_3
        switch mode {
        case .perfectSync:
            return vrmPerfectSyncKeyDefinitions
        case .blendShape:
            return vrmBlendShapeKeyDefinitions
        }
#else
        switch mode {
        case .perfectSync:
            return live2DPerfectSyncKeyDefinitions
        case .blendShape:
            return live2DBlendShapeKeyDefinitions
        }
#endif
    }

#if FEATURE_3
    private static let vrmPerfectSyncKeyDefinitions: [InputKey] = [
        .posX, .posY, .posZ,
        .headX, .headY, .headZ,
        .eyeX, .eyeY,
        // ARKit BlendShapes
        .browDownLeft, .browDownRight, .browInnerUp,
        .browOuterUpLeft, .browOuterUpRight,
        .cheekPuff, .cheekSquintLeft, .cheekSquintRight,
        .eyeBlinkLeft, .eyeBlinkRight,
        .eyeLookDownLeft, .eyeLookDownRight,
        .eyeLookInLeft, .eyeLookInRight,
        .eyeLookOutLeft, .eyeLookOutRight,
        .eyeLookUpLeft, .eyeLookUpRight,
        .eyeSquintLeft, .eyeSquintRight,
        .eyeWideLeft, .eyeWideRight,
        .jawForward, .jawLeft, .jawOpen, .jawRight,
        .mouthClose, .mouthDimpleLeft, .mouthDimpleRight,
        .mouthFrownLeft, .mouthFrownRight, .mouthFunnel, .mouthLeft,
        .mouthLowerDownLeft, .mouthLowerDownRight,
        .mouthPressLeft, .mouthPressRight, .mouthPucker, .mouthRight,
        .mouthRollLower, .mouthRollUpper, .mouthShrugLower, .mouthShrugUpper,
        .mouthSmileLeft, .mouthSmileRight, .mouthStretchLeft, .mouthStretchRight,
        .mouthUpperUpLeft, .mouthUpperUpRight,
        .noseSneerLeft, .noseSneerRight, .tongueOut
    ]

    private static let vrmBlendShapeKeyDefinitions: [InputKey] = [
        .posX, .posY, .posZ,
        .headX, .headY, .headZ,
        .blinkL, .blinkR,
        .mouth,
        .eyeX, .eyeY
    ]
#else
    private static let live2DPerfectSyncKeyDefinitions: [InputKey] = live2DBlendShapeKeyDefinitions

    private static let live2DBlendShapeKeyDefinitions: [InputKey] = [
        .posX, .posY, .posZ,
        .headX, .headY, .headZ,
        .blinkL, .blinkR,
        .mouth,
        .eyeX, .eyeY
    ]
#endif

    static func availableInputKeys(for mode: TrackingMode) -> [InputKey] {
        inputKeyDefinitions(for: mode)
    }

    static func defaultMappings(for mode: TrackingMode) -> [TrackingMappingEntry] {
        inputKeyDefinitions(for: mode)
            .map { TrackingMappingEntry(input: $0, outputKey: .init(key: $0.key, bounds: $0.bounds)) }
    }
}
