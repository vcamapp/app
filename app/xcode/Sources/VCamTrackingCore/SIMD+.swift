import simd
import struct CoreGraphics.CGPoint

public extension SIMD2<Float> {
    @inlinable init(_ point: CGPoint) {
        self = .init(Float(point.x), Float(point.y))
    }
}

public extension simd_float4x4 {
    @inlinable var translation: SIMD3<Float> {
        let p = columns.3
        return .init(p.x, p.y, p.z)
    }

    @inlinable var rotation: simd_quatf {
        simd_quatf(self)
    }

    @inlinable var axisX: Self {
        .init(
            SIMD4(1, 0, 0, 0),
            SIMD4(0, columns.1.y, columns.2.y, 0),
            SIMD4(0, columns.1.z, columns.2.z, 0),
            SIMD4(0, 0, 0, 1)
        )
    }

    /// The rotation part with the translation dropped.
    @inlinable var rotationOnly: Self {
        .init(
            SIMD4(columns.0.x, columns.0.y, columns.0.z, 0),
            SIMD4(columns.1.x, columns.1.y, columns.1.z, 0),
            SIMD4(columns.2.x, columns.2.y, columns.2.z, 0),
            SIMD4(0, 0, 0, 1)
        )
    }

    /// Whether the transform is a reflection (left-handed, negative determinant).
    @inlinable var isMirrored: Bool {
        simd_determinant(self) < 0
    }
}

public extension simd_quatf {
    /// Euler angles in radians (x: pitch, y: yaw, z: roll), applied yaw then pitch then roll about
    /// the intrinsic axes to match how the engine composes them. `eulerAngles()` must decompose in
    /// the same order, or roll leaks into pitch as yaw grows (18° off at 60° yaw with 10° roll).
    @inlinable init(_ radianAngles: SIMD3<Float>) {
        self = simd_quatf(angle: radianAngles.y, axis: SIMD3(0, 1, 0))
            * simd_quatf(angle: radianAngles.x, axis: SIMD3(1, 0, 0))
            * simd_quatf(angle: radianAngles.z, axis: SIMD3(0, 0, 1))
    }

    /// The inverse of `init(_:)`, in degrees. Straight up or down (±90° pitch) leaves yaw and roll
    /// on the same axis, so the whole rotation goes to yaw.
    @inlinable func eulerAngles() -> SIMD3<Float> {
        let q = simd_normalize(self)
        let x = q.imag.x, y = q.imag.y, z = q.imag.z, w = q.real
        let sinPitch = 2 * (w * x - y * z)
        let pitch: Float
        let yaw: Float
        let roll: Float
        if abs(sinPitch) > 0.9999 {
            pitch = copysign(.pi / 2, sinPitch)
            yaw = atan2(2 * (w * y - x * z), 1 - 2 * (y * y + z * z))
            roll = 0
        } else {
            pitch = asin(sinPitch)
            yaw = atan2(2 * (w * y + x * z), 1 - 2 * (x * x + y * y))
            roll = atan2(2 * (w * z + x * y), 1 - 2 * (x * x + z * z))
        }
        return SIMD3(pitch, yaw, roll) * (180 / .pi)
    }

    /// The shortest rotation to `other` in radians. `(inverse * other).angle` reports nearly 2π for
    /// the same rotation with the opposite sign (the double cover), and quaternions built from
    /// matrices flip sign freely, so the dot product is folded instead.
    @inlinable func angle(to other: simd_quatf) -> Float {
        let cosine = abs(simd_dot(simd_normalize(self).vector, simd_normalize(other).vector))
        return 2 * acos(min(1, cosine))
    }

    @inlinable func degrees(to other: simd_quatf) -> Float {
        angle(to: other) * 180 / .pi
    }
}
