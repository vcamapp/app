import Testing
import CoreServices
import CoreVideo
import VCamEntity

@Suite
struct FourCharCodeTests {
    @Test
    func unknown() throws {
        let code: FourCharCode = "invalid string"
        #expect(code == FourCharCode(kUnknownType))
        #expect(code.string == "????")
    }

    @Test(arguments: [
        ("420v", kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
        ("420f", kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
        ("BGRA", kCVPixelFormatType_32BGRA),
    ])
    func roundTripsPixelFormatCodes(string: String, expected: OSType) {
        let code = FourCharCode(stringLiteral: string)
        #expect(code == expected)
        #expect(code.string == string)
    }
}
