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

    @Test(arguments: [
        (angle: Float.pi, axis: SIMD3<Float>(1, 0, 0)),
        (angle: .pi, axis: SIMD3<Float>(0, 1, 0)),
        (angle: .pi, axis: SIMD3<Float>(0, 0, 1)),
        (angle: .pi, axis: simd_normalize(SIMD3<Float>(0.5, 0.5, 0))),
        (angle: .pi, axis: simd_normalize(SIMD3<Float>(0, 0.5, 0.5))),
        (angle: 2 as Float, axis: simd_normalize(SIMD3<Float>(0.3, 0.3, 0.4))),
    ])
    func eulerAnglesMatchSceneKit(rotation: (angle: Float, axis: SIMD3<Float>)) {
        let rotation = simd_quatf(angle: rotation.angle, axis: rotation.axis)
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
