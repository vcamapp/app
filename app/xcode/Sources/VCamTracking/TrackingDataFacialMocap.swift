//
//  TrackingDataFacialMocap.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/12/30.
//

import Foundation
import simd

public struct FacialMocapData: Equatable {
    public let blendShapes: [String: Int]
    public let head: Head
    public let rightEye: Eye
    public let leftEye: Eye

    public struct Head: Equatable {
        public let rotation: SIMD3<Float>
        public let translation: SIMD3<Float>

        public var rotationRadian: SIMD3<Float> {
            .init(rotation.x * .pi / 180, rotation.y * .pi / 180, rotation.z * .pi / 180)
        }
    }

    public struct Eye: Equatable {
        public let rotation: SIMD3<Float>
    }
}

public extension FacialMocapData {
    init?(rawData: String) {
        let blendShapeAndTransformRawData = rawData.components(separatedBy: "=")
        guard blendShapeAndTransformRawData.count == 2 else {
            return nil
        }
        let blendShapeRawData = blendShapeAndTransformRawData[0]
        let transformRawData = blendShapeAndTransformRawData[1]

        var blendShapes: [String: Int] = [:]

        for blendShape in blendShapeRawData.components(separatedBy: "|").filter({ !$0.isEmpty }) {
            let blendShapeAndValue = blendShape.components(separatedBy: "&")
            guard blendShapeAndValue.count == 2, let value = Int(blendShapeAndValue[1]) else {
                return nil
            }
            blendShapes[blendShapeAndValue[0]] = value
        }

        let transforms: [Float] = transformRawData
            .components(separatedBy: "|")
            .filter { !$0.isEmpty }
            .flatMap {
                $0.components(separatedBy: "#").last?.components(separatedBy: ",").compactMap(Float.init) ?? []
            }

        guard transforms.count == 12 else {
            return nil
        }

        self.blendShapes = blendShapes
        self.head = .init(
            rotation: SIMD3(transforms[0...2]),
            translation: SIMD3(transforms[3...5])
        )
        self.rightEye = .init(rotation: SIMD3(transforms[6...8]))
        self.leftEye = .init(rotation: SIMD3(transforms[9...11]))
    }
}
