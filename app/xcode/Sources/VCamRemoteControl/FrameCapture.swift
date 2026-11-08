import CoreImage
import Foundation

enum FrameCapture {
    private static let context = CIContext()

    /// Encoding a full frame takes long enough to drop frames on the main actor
    @concurrent
    static func encode(_ image: CIImage, maxWidth: Int?, format: FrameCaptureFormat) async throws -> FrameCaptureResult {
        let scale = maxWidth.map { min(CGFloat($0) / image.extent.width, 1) } ?? 1
        // Viewers of the output see the color channels alone, so the alpha of a transparent background must not show
        let scaled = image.transformedToOrigin(scale: scale).settingAlphaOne(in: image.extent.scaled(by: scale))
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let data: Data? = switch format {
        case .png: context.pngRepresentation(of: scaled, format: .RGBA8, colorSpace: colorSpace)
        case .jpeg: context.jpegRepresentation(of: scaled, colorSpace: colorSpace)
        }
        guard let data else {
            throw JSONRPCErrorObject(code: -32603, message: "Failed to encode the frame")
        }
        return FrameCaptureResult(
            data: data.base64EncodedString(),
            height: Int(scaled.extent.height),
            mimeType: format == .png ? "image/png" : "image/jpeg",
            width: Int(scaled.extent.width)
        )
    }
}

private extension CGRect {
    func scaled(by scale: CGFloat) -> CGRect {
        CGRect(x: 0, y: 0, width: width * scale, height: height * scale)
    }
}

private extension CIImage {
    func transformedToOrigin(scale: CGFloat) -> CIImage {
        let scaled = transformed(by: .init(scaleX: scale, y: scale))
        return scaled.transformed(by: .init(translationX: -scaled.extent.minX, y: -scaled.extent.minY))
    }
}
