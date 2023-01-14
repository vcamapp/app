//
//  FacialDataVCamMotion.swift
//
//
//  Created by Tatsuya Tanaka on 2023/01/09.
//

import Foundation
import simd

public struct VCamMotion: Equatable {
    public var version: UInt32
    public var head: Head
    public var hands: Hands
    public var blendShape: BlendShape

    public struct Head: Equatable {
        public var translation: SIMD3<Float>
        public var rotation: SIMD4<Float>
    }
    public struct Hands: Equatable {
        public var right: Hand
        public var left: Hand
    }

    public struct Hand: Equatable {
        public init(wrist: SIMD2<Float>, thumbCMC: SIMD2<Float>, littleMCP: SIMD2<Float>, thumbTip: SIMD2<Float>, indexTip: SIMD2<Float>, middleTip: SIMD2<Float>, ringTip: SIMD2<Float>, littleTip: SIMD2<Float>) {
            self.wrist = wrist
            self.thumbCMC = thumbCMC
            self.littleMCP = littleMCP
            self.thumbTip = thumbTip
            self.indexTip = indexTip
            self.middleTip = middleTip
            self.ringTip = ringTip
            self.littleTip = littleTip
        }

        public var wrist: SIMD2<Float>
        public var thumbCMC: SIMD2<Float>
        public var littleMCP: SIMD2<Float>
        public var thumbTip: SIMD2<Float>
        public var indexTip: SIMD2<Float>
        public var middleTip: SIMD2<Float>
        public var ringTip: SIMD2<Float>
        public var littleTip: SIMD2<Float>
    }

    public struct BlendShape: Equatable {
        public var browDownLeft: Float
        public var browDownRight: Float
        public var browInnerUp: Float
        public var browOuterUpLeft: Float
        public var browOuterUpRight: Float
        public var cheekPuff: Float
        public var cheekSquintLeft: Float
        public var cheekSquintRight: Float
        public var eyeBlinkLeft: Float
        public var eyeBlinkRight: Float
        public var eyeLookDownLeft: Float
        public var eyeLookDownRight: Float
        public var eyeLookInLeft: Float
        public var eyeLookInRight: Float
        public var eyeLookOutLeft: Float
        public var eyeLookOutRight: Float
        public var eyeLookUpLeft: Float
        public var eyeLookUpRight: Float
        public var eyeSquintLeft: Float
        public var eyeSquintRight: Float
        public var eyeWideLeft: Float
        public var eyeWideRight: Float
        public var jawForward: Float
        public var jawLeft: Float
        public var jawOpen: Float
        public var jawRight: Float
        public var mouthClose: Float
        public var mouthDimpleLeft: Float
        public var mouthDimpleRight: Float
        public var mouthFrownLeft: Float
        public var mouthFrownRight: Float
        public var mouthFunnel: Float
        public var mouthLeft: Float
        public var mouthLowerDownLeft: Float
        public var mouthLowerDownRight: Float
        public var mouthPressLeft: Float
        public var mouthPressRight: Float
        public var mouthPucker: Float
        public var mouthRight: Float
        public var mouthRollLower: Float
        public var mouthRollUpper: Float
        public var mouthShrugLower: Float
        public var mouthShrugUpper: Float
        public var mouthSmileLeft: Float
        public var mouthSmileRight: Float
        public var mouthStretchLeft: Float
        public var mouthStretchRight: Float
        public var mouthUpperUpLeft: Float
        public var mouthUpperUpRight: Float
        public var noseSneerLeft: Float
        public var noseSneerRight: Float
        public var tongueOut: Float
    }
}

// MARK: - Initializer

public extension VCamMotion {
    init(rawData: Data) {
        self = rawData.withUnsafeBytes { $0.load(as: Self.self) }
    }

    mutating func dataNoCopy() -> Data {
        Data(valueNoCopy: &self)
    }
}

public extension VCamMotion.Head {
    init(transform: simd_float4x4) {
        translation = transform.translation
        rotation = transform.rotation.vector
    }
}

extension Data {
    init<T>(valueNoCopy value: inout T) {
        self = Data(bytesNoCopy: &value, count: MemoryLayout<T>.size, deallocator: .none)
    }
}

// MARK: - Utilities

public extension VCamMotion.Hands {
    func lerp(next: Self, t: Float = 0.22) -> Self {
        .init(
            right: right.lerp(next: next.right, t: t),
            left: left.lerp(next: next.left, t: t)
        )
    }
}

public extension VCamMotion.Hand {
    var isInvalid: Bool {
        wrist.x == 0 && wrist.y == 0
    }

    static var missing: Self {
        .init(wrist: .zero, thumbCMC: .zero, littleMCP: .zero, thumbTip: .zero, indexTip: .zero, middleTip: .zero, ringTip: .zero, littleTip: .zero)
    }

    func lerp(next: Self, t: Float) -> Self {
        if self == .missing {
            return next
        } else if next == .missing {
            return .missing
        }
        return .init(
            wrist: mix(wrist, next.wrist, t: t),
            thumbCMC: mix(thumbCMC, next.thumbCMC, t: t),
            littleMCP: mix(littleMCP, next.littleMCP, t: t),
            thumbTip: mix(thumbTip, next.thumbTip, t: t),
            indexTip: mix(indexTip, next.indexTip, t: t),
            middleTip: mix(middleTip, next.middleTip, t: t),
            ringTip: mix(ringTip, next.ringTip, t: t),
            littleTip: mix(littleTip, next.littleTip, t: t)
        )
    }
}
