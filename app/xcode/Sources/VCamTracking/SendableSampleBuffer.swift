import CoreMedia

// TODO: CMReadySampleBuffer<Content> is available on macOS 26+ and Sendable
struct SendableSampleBuffer: @unchecked Sendable {
    let value: CMSampleBuffer

    init(_ value: CMSampleBuffer) {
        self.value = value
    }
}
