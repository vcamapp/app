import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public extension CGImage {
    func pngData() -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, self, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    func writeAsPNG(to destination: URL) throws {
        guard let imageData = pngData() else {
            throw NSError(domain: "vcam", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to get PNG representation. url: \(destination)"])
        }
        try imageData.write(to: destination)
    }
}
