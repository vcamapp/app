//
//  CapturedFrame.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/06/25.
//

import CoreImage

public struct CapturedFrame {
    public init(buffer: CVPixelBuffer) {
        self.buffer = buffer
    }

    public let buffer: CVPixelBuffer

    public var surfaceRef: IOSurfaceRef? {
        CVPixelBufferGetIOSurface(buffer)?.takeUnretainedValue()
    }

    public var surface: IOSurface? {
        guard let surfaceRef = surfaceRef else { return nil }
        // Force-cast the IOSurfaceRef to IOSurface.
        return unsafeBitCast(surfaceRef, to: IOSurface.self)
    }

    public var ciImage: CIImage {
        CIImage(cvPixelBuffer: buffer)
    }

    public var size: (width: Int, height: Int) {
        (width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer))
    }
}
