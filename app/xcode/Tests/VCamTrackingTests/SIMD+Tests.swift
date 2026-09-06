import Testing
import simd
import VCamTracking

@Suite
struct SIMDTests {
    @Test
    func piX1() {
        // Pitch is clamped to ±90°, so a 180° pitch decomposes as (0, 180, 180) and still round-trips.
        let rotation = simd_quatf(angle: .pi, axis: .init(1, 0, 0))
        let angle = rotation.eulerAngles()
        #expect(abs(angle.x) < 0.01)
        #expect(simd_quatf(angle * .pi / 180).degrees(to: rotation) < 0.01)
    }

    @Test
    func composesYawThenPitchThenRoll() {
        let angles = SIMD3<Float>(-15, 60, 10) * .pi / 180
        let expected = simd_quatf(angle: angles.y, axis: SIMD3(0, 1, 0))
            * simd_quatf(angle: angles.x, axis: SIMD3(1, 0, 0))
            * simd_quatf(angle: angles.z, axis: SIMD3(0, 0, 1))
        #expect(simd_quatf(angles).degrees(to: expected) < 0.01)
    }

    @Test(arguments: [
        SIMD3<Float>(-15, 60, 10),
        SIMD3<Float>(-15, 45, 0),
        SIMD3<Float>(20, -70, -15),
        SIMD3<Float>(5, 170, 30),
        SIMD3<Float>(-80, 30, 20),
    ])
    func eulerAnglesRoundTrip(angles: SIMD3<Float>) {
        let decomposed = simd_quatf(angles * .pi / 180).eulerAngles()
        #expect(decomposed.isApproximatelyEqual(to: angles, accuracy: 0.01))
    }

    @Test
    func straightUpKeepsYawAndDropsRoll() {
        let rotation = simd_quatf(SIMD3<Float>(90, 30, 20) * .pi / 180)
        let angles = rotation.eulerAngles()
        #expect(abs(angles.x - 90) < 0.01)
        #expect(angles.z == 0)
        #expect(simd_quatf(angles * .pi / 180).degrees(to: rotation) < 0.01)
    }
}

private extension SIMD3 where Scalar == Float {
    func isApproximatelyEqual(to other: SIMD3<Float>, accuracy: Float) -> Bool {
        abs(x - other.x) <= accuracy &&
        abs(y - other.y) <= accuracy &&
        abs(z - other.z) <= accuracy
    }
}
