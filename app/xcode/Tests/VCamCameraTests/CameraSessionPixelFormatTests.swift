import CoreVideo
import Testing
import VCamCamera

@Suite
struct CameraSessionPixelFormatTests {
    @Test
    func defaultFollowsVideoRangeCamera() {
        let format = CameraSession.effectivePixelFormat(
            requested: CameraSession.defaultPixelFormat,
            deviceMediaSubType: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        )
        #expect(format == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
    }

    @Test
    func defaultStaysFullRangeForOtherCameras() {
        for subType in [kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, kCVPixelFormatType_32BGRA, kCVPixelFormatType_422YpCbCr8] {
            let format = CameraSession.effectivePixelFormat(requested: CameraSession.defaultPixelFormat, deviceMediaSubType: subType)
            #expect(format == CameraSession.defaultPixelFormat)
        }
        #expect(CameraSession.effectivePixelFormat(requested: CameraSession.defaultPixelFormat, deviceMediaSubType: nil) == CameraSession.defaultPixelFormat)
    }

    @Test
    func explicitRequestIsKept() {
        let format = CameraSession.effectivePixelFormat(
            requested: kCVPixelFormatType_32BGRA,
            deviceMediaSubType: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        )
        #expect(format == kCVPixelFormatType_32BGRA)
    }
}
