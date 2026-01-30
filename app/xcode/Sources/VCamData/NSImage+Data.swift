import AppKit

extension NSBitmapImageRep {
    var png: Data? {
        representation(using: .png, properties: [:])
    }
}

extension Data {
    var bitmap: NSBitmapImageRep? {
        NSBitmapImageRep(data: self)
    }
}

extension NSImage {
    var png: Data? {
        tiffRepresentation?.bitmap?.png
    }
}
