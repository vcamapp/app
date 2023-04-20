//
//  ChromaKey.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/06/14.
//

import CoreImage.CIFilterBuiltins

enum ChromaKey {
    static func filter(
        red targetRed: Float,
        green targetGreen: Float,
        blue targetBlue: Float,
        threshold: Float
    ) -> any CIFilter & CIColorCube {
        let size = 64
        let buffer = UnsafeMutableBufferPointer<Float>.allocate(capacity: size * size * size * 4)

        var offset = 0

        let range: StrideTo<Float> = stride(from: 0, to: 1, by: 1 / Float(size))
        for blue in range {
            for green in range {
                for red in range {
                    let distance = pow(red - targetRed, 2)
                        + pow(green - targetGreen, 2)
                        + pow(blue - targetBlue, 2)
                    let alpha: Float = distance < threshold ? 0.0 : 1.0

                    buffer[offset    ] = red * alpha
                    buffer[offset + 1] = green * alpha
                    buffer[offset + 2] = blue * alpha
                    buffer[offset + 3] = alpha
                    offset += 4
                }
            }
        }

        let filter = CIFilter.colorCube()
        filter.cubeDimension = Float(size)
        filter.cubeData = Data(bytesNoCopy: buffer.baseAddress!, count: buffer.count * MemoryLayout<Float>.size, deallocator: .free)
        return filter
    }
}
