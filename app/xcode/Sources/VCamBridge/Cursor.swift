import AppKit
import VCamUIFoundation

public enum CursorType: Int {
    case northWestSouthEastResize
    case northEastSouthWestResize
    case move

    public var path: String {
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
