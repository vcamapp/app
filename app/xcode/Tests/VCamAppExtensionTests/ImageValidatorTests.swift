import Testing
@testable import VCamAppExtension

@Suite
struct ImageValidatorTests {
    @Test
    func encodeDecode() {
        let imageData = Data((1...5000).map { _ in UInt8.random(in: 0..<UInt8.max) })

        let width = 1000
        let height = 5
        let encoded = ImageValidator.dataWithChecksum(from: imageData, width: width, height: height)

        let (isStart, isEnd, needsMoreData) = ImageValidator.inspect(encoded)
        #expect(isStart)
        #expect(isEnd)
        #expect(!needsMoreData)

        let (decoded, decodedWidth, decodedHeight) = ImageValidator.extractImageData(from: encoded)
        #expect(imageData == decoded)
        #expect(width == decodedWidth)
        #expect(height == decodedHeight)
    }
}
