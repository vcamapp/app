//
//  SIMD+.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/10/15.
//

import simd

public extension SIMD3 where Scalar == Float {
    static let axisX = SIMD3(1, 0, 0)
    static let axisY = SIMD3(0, 1, 0)
    static let axisZ = SIMD3(0, 0, 1)
}

public extension SIMD3 where Scalar == Double {
    static let axisX = SIMD3(1, 0, 0)
    static let axisY = SIMD3(0, 1, 0)
    static let axisZ = SIMD3(0, 0, 1)
}

public extension simd_float4x4 {
    var translation: SIMD3<Float> {
        let p = columns.3
        return .init(p.x, p.y, p.z)
    }

    var rotation: simd_quatf {
        var rotation = self
        rotation.columns.3 = .zero // remove translation
        var result = simd_quatf(rotation)
        result.vector = -result.vector // right-handed coordinates to left-handed coordinates
        return result
    }
}

public extension simd_quatf {
    init(_ eulerAngles: SIMD3<Float>) {
        let cz = cos(eulerAngles.z * 0.5)
        let sz = sin(eulerAngles.z * 0.5)
        let cy = cos(eulerAngles.y * 0.5)
        let sy = sin(eulerAngles.y * 0.5)
        let cx = cos(eulerAngles.x * 0.5)
        let sx = sin(eulerAngles.x * 0.5)

        self.init(vector: [
            sx * cy * cz - cx * sy * sz,
            cx * sy * cz + sx * cy * sz,
            cx * cy * sz - sx * sy * cz,
            cx * cy * cz + sx * sy * sz,
        ])
    }

    init(_ quat: simd_quatd) {
      self.init(vector: SIMD4<Float>(Float(quat.vector[0]), Float(quat.vector[1]), Float(quat.vector[2]), Float(quat.vector[3])))
    }
}

extension simd_quatd {
    init(_ eulerAngles: SIMD3<Double>) {
        let cz = cos(eulerAngles.z * 0.5)
        let sz = sin(eulerAngles.z * 0.5)
        let cy = cos(eulerAngles.y * 0.5)
        let sy = sin(eulerAngles.y * 0.5)
        let cx = cos(eulerAngles.x * 0.5)
        let sx = sin(eulerAngles.x * 0.5)

        self.init(vector: [
            sx * cy * cz - cx * sy * sz,
            cx * sy * cz + sx * cy * sz,
            cx * cy * sz - sx * sy * cz,
            cx * cy * cz + sx * sy * sz,
        ])
    }
}
