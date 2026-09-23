import CoreImage

public struct CapturedFrame {
    public init(buffer: CVPixelBuffer) {
        self.buffer = buffer
    }

    public let buffer: CVPixelBuffer

    public var ciImage: CIImage {
        CIImage(cvPixelBuffer: buffer)
    }
}
