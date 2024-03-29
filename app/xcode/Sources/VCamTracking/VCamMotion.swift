//
//  VCamMotion.swift
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
        public var rotation: simd_quatf
    }
    public struct Hands: Equatable {
        public init(right: VCamMotion.Hand, left: VCamMotion.Hand) {
            self.right = right
            self.left = left
        }

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
}

// MARK: - Initializer

public extension VCamMotion {
    init(rawData: Data) {
        self = rawData.load()
    }

    mutating func dataNoCopy() -> Data {
        Data(valueNoCopy: &self, count: MemoryLayout<Self>.size)
    }
}

private extension Data {
    init(valueNoCopy value: UnsafeMutableRawPointer, count: Int) {
        self = Data(bytesNoCopy: value, count: count, deallocator: .none)
    }

    func load<T>() -> T {
        withUnsafeBytes { $0.load(as: T.self) }
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
        if self == .missing || next == .missing {
            return next
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

    func translated(_ offset: SIMD2<Float>) -> Self {
        var newValue = self
        newValue.wrist += offset
        newValue.thumbCMC += offset
        newValue.littleMCP += offset
        newValue.thumbTip += offset
        newValue.indexTip += offset
        newValue.middleTip += offset
        newValue.ringTip += offset
        newValue.littleTip += offset
        return newValue
    }
}
