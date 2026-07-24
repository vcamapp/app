//
//  NSImage+.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/06/13.
//

import AppKit
import CoreImage

public extension NSImage {
    convenience init(color: NSColor, size: NSSize) {
        self.init(size: size)
        lockFocus()
        color.drawSwatch(in: NSRect(origin: .zero, size: size))
        unlockFocus()
    }
    
    var ciImage: CIImage? {
        guard let imageData = self.tiffRepresentation else { return nil }
        return CIImage(data: imageData)
    }

    func pngData() -> Data? {
        guard let tiffData = tiffRepresentation else { return nil }
        return NSBitmapImageRep(data: tiffData)?.representation(using: .png, properties: [:])
    }

    func writeAsPNG(to destination: URL) throws {
        guard let imageData = pngData() else {
            throw NSError(domain: "vcam", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to get PNG representation. url: \(destination)"])
        }
        try imageData.write(to: destination)
    }
}
