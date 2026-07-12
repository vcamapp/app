import CoreGraphics
import CoreMedia

// TODO: CMReadySampleBuffer<Content> is available on macOS 26+ and Sendable
public struct CameraSampleBuffer: @unchecked Sendable {
    public let value: CMSampleBuffer

    public init(_ value: CMSampleBuffer) {
        self.value = value
    }
}

public struct CameraFrame: Sendable {
    public let sampleBuffer: CameraSampleBuffer
    public let timestamp: CMTime
    public let captureSize: CGSize

    public init(
        sampleBuffer: CameraSampleBuffer,
        timestamp: CMTime,
        captureSize: CGSize
    ) {
        self.sampleBuffer = sampleBuffer
        self.timestamp = timestamp
        self.captureSize = captureSize
    }
}

public typealias CameraFrameHandler = @Sendable (CameraFrame) -> Void
