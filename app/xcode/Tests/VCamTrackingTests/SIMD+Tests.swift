import Testing
import simd
import SceneKit
import VCamTracking


@Suite
struct SIMDTests {
    @Test
    func piX1() {
        let rotation = simd_quatf(angle: .pi, axis: .init(1, 0, 0))
        let angle = rotation.eulerAngles()
        #expect(angle == .init(180, 0, 0))
    }

    @Test
    func piX1MatchesSceneKit() {
        let rotation = simd_quatf(angle: .pi, axis: .init(1, 0, 0))
        #expect(rotation.eulerAngles() == quaternionToEulerAngles(rotation))
    }

    @Test
    func piY1MatchesSceneKit() {
        let rotation = simd_quatf(angle: .pi, axis: .init(0, 1, 0))
        #expect(rotation.eulerAngles() == quaternionToEulerAngles(rotation))
    }

    @Test
    func piZ1MatchesSceneKit() {
        let rotation = simd_quatf(angle: .pi, axis: .init(0, 0, 1))
        #expect(rotation.eulerAngles() == quaternionToEulerAngles(rotation))
    }

    @Test
    func piXY05MatchesSceneKit() {
        let rotation = simd_quatf(angle: .pi, axis: simd_normalize(.init(0.5, 0.5, 0)))
        #expect(rotation.eulerAngles().isApproximatelyEqual(to: quaternionToEulerAngles(rotation), accuracy: 0.01))
    }

    @Test
    func piYZ05MatchesSceneKit() {
        let rotation = simd_quatf(angle: .pi, axis: simd_normalize(.init(0, 0.5, 0.5)))
        #expect(rotation.eulerAngles().isApproximatelyEqual(to: quaternionToEulerAngles(rotation), accuracy: 0.01))
    }

    @Test
    func arbitraryAxisMatchesSceneKit() {
        let rotation = simd_quatf(angle: 2, axis: simd_normalize(.init(0.3, 0.3, 0.4)))
        #expect(rotation.eulerAngles().isApproximatelyEqual(to: quaternionToEulerAngles(rotation), accuracy: 0.01))
    }
}

private extension SIMDTests {
    func quaternionToEulerAngles(_ rotation: simd_quatf) -> SIMD3<Float> {
        let node = SCNNode()
        node.simdOrientation = rotation
        return node.simdEulerAngles * 180 / .pi
    }
}

private extension SIMD3 where Scalar == Float {
    func isApproximatelyEqual(to other: SIMD3<Float>, accuracy: Float) -> Bool {
        abs(x - other.x) <= accuracy &&
        abs(y - other.y) <= accuracy &&
        abs(z - other.z) <= accuracy
    }
}
