//
//  RevisedMovingAverage.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/07/31.
//

import Accelerate
import simd

public protocol RevisedMovingAverageValue {
    static var zero: Self { get }
    static func +(_ lhs: Self, _ rhs: Self) -> Self
    static func *(_ lhs: Self, _ rhs: Float) -> Self
}

extension Float: RevisedMovingAverageValue {}
extension SIMD2<Float>: RevisedMovingAverageValue {}
extension SIMD3<Float>: RevisedMovingAverageValue {}
extension SIMD4<Float>: RevisedMovingAverageValue {}

public struct RevisedMovingAverage<Value: RevisedMovingAverageValue> {
    private let weights: [Float]
    private var previousValues: [Value]

    private var latestValueIndex: Int
    private let valueRange: Range<Int>

    public var latestValue: Value {
        previousValues[latestValueIndex]
    }

    public init(weight: RevisedMovingAverageWeight) {
        weights = weight.weights
        previousValues = Array(repeating: .zero, count: weights.count)
        latestValueIndex = previousValues.count - 1
        valueRange = 0..<previousValues.count
    }

    public mutating func appending(_ newValue: Value) -> Value {
        // https://www.jstage.jst.go.jp/article/kakoronbunshu1975/24/4/24_4_686/_pdf

        let nextValueIndex = (latestValueIndex + 1) % previousValues.count
        defer {
            latestValueIndex = nextValueIndex
        }

        previousValues[latestValueIndex] = newValue

        return valueRange.reduce(Value.zero) { partialResult, index in
            partialResult + previousValues[(nextValueIndex + index) % previousValues.count] * weights[index]
        }
    }

    public mutating func setValues(_ newValue: Value) {
        previousValues = Array(repeating: newValue, count: weights.count)
    }
}

public enum RevisedMovingAverageWeight {
    case four
    case six

    var weights: [Float] {
        switch self {
        case .four: return Self.weights4
        case .six: return Self.weights6
        }
    }

    private static let weights4 = calculateWeight(count: 4)
    private static let weights6 = calculateWeight(count: 6)

    private static func calculateWeight(count: Int, weight: Float = 60) -> [Float] {
        let base: Float = (0..<count).reduce(Float.zero) { partialResult, index in
            partialResult + exp(Float(index) / weight)
        }

        return (0..<count).map {
            exp(Float($0) / weight) / base
        }
    }
}
