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

    @Test
    func videoRange420v() {
        let code: FourCharCode = "420v"
        #expect(code == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
        #expect(code.string == "420v")
    }

    @Test
    func fullRange420f() {
        let code: FourCharCode = "420f"
        #expect(code == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
        #expect(code.string == "420f")
    }

    @Test
    func bgra() {
        let code: FourCharCode = "BGRA"
        #expect(code == kCVPixelFormatType_32BGRA)
        #expect(code.string == "BGRA")
    }
}
