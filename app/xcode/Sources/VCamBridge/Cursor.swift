import AppKit
import VCamUIFoundation

enum CursorType: Int {
    case northWestSouthEastResize
    case northEastSouthWestResize
    case move

    var path: String {
        switch self {
        case .northWestSouthEastResize:
            return "/System/Library/Frameworks/WebKit.framework/Versions/Current/Frameworks/WebCore.framework/Resources/northWestSouthEastResizeCursor.png"
        case .northEastSouthWestResize:
            return "/System/Library/Frameworks/WebKit.framework/Versions/Current/Frameworks/WebCore.framework/Resources/northEastSouthWestResizeCursor.png"
        case .move:
            return "/System/Library/Frameworks/WebKit.framework/Versions/Current/Frameworks/WebCore.framework/Resources/moveCursor.png"
        }
    }
}

@_cdecl("uniPushCursor")
@MainActor public func uniPushCursor(_ type: Int) {
    guard let cursor = CursorType(rawValue: type) else { return }
    switch cursor {
    case .northWestSouthEastResize, .northEastSouthWestResize, .move:
        guard let image = NSImage(contentsOf: .init(fileURLWithPath: cursor.path)) else { return }
        NSCursor(image: image, hotSpot: .init(x: image.size.width / 2, y: image.size.height / 2)).pushForSwiftUI()
    }
}

@_cdecl("uniPopCursor")
@MainActor public func uniPopCursor() {
    NSCursor.popForSwiftUI()
}
