import CoreMedia

struct SendableCMSampleBuffer: @unchecked Sendable { // TODO: Use CMReadySampleBuffer if macOS 26+
    let value: CMSampleBuffer

    init(_ value: CMSampleBuffer) {
        self.value = value
    }
}
