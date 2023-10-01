//
//  SIMD+Tests.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/10/01.
//

import XCTest
import simd
import SceneKit
import VCamTracking


final class SIMDTests: XCTestCase {
    func test_pi_x1() throws {
        let rotation = simd_quatf(angle: .pi, axis: .init(1, 0, 0))
        let angle = rotation.eulerAngles()
        XCTAssertEqual(angle, .init(180, 0, 0))
    }

    func test_pi_x1_2() throws {
        let rotation = simd_quatf(angle: .pi, axis: .init(1, 0, 0))
        XCTAssertEqual(rotation.eulerAngles(), quaternionToEulerAngles(rotation))
    }

    func test_pi_y1() throws {
        let rotation = simd_quatf(angle: .pi, axis: .init(0, 1, 0))
        XCTAssertEqual(rotation.eulerAngles(), quaternionToEulerAngles(rotation))
    }

    func test_pi_z1() throws {
        let rotation = simd_quatf(angle: .pi, axis: .init(0, 0, 1))
        XCTAssertEqual(rotation.eulerAngles(), quaternionToEulerAngles(rotation))
    }

    func test_pi_xy05() throws {
        let rotation = simd_quatf(angle: .pi, axis: simd_normalize(.init(0.5, 0.5, 0)))
        XCTAssertSIMDEqual(rotation.eulerAngles(), quaternionToEulerAngles(rotation), accuracy: 0.01)
    }

    func test_pi_yz05() throws {
        let rotation = simd_quatf(angle: .pi, axis: simd_normalize(.init(0, 0.5, 0.5)))
        XCTAssertSIMDEqual(rotation.eulerAngles(), quaternionToEulerAngles(rotation), accuracy: 0.01)
    }

    func test_2_x03_y03_z04() throws {
        let rotation = simd_quatf(angle: 2, axis: simd_normalize(.init(0.3, 0.3, 0.4)))
        XCTAssertSIMDEqual(rotation.eulerAngles(), quaternionToEulerAngles(rotation), accuracy: 0.01)
    }
}

private extension SIMDTests {
    func quaternionToEulerAngles(_ rotation: simd_quatf) -> SIMD3<Float> {
        let node = SCNNode()
        node.simdOrientation = rotation
        return node.simdEulerAngles * 180 / .pi
    }

    func XCTAssertSIMDEqual(_ expression1: SIMD3<Float>, _ expression2: SIMD3<Float>, accuracy: Float) {
        XCTAssertEqual(expression1.x, expression2.x, accuracy: accuracy)
        XCTAssertEqual(expression1.y, expression2.y, accuracy: accuracy)
        XCTAssertEqual(expression1.z, expression2.z, accuracy: accuracy)
    }
}
