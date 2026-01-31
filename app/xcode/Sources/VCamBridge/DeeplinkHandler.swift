import Foundation

@_cdecl("uniHandleDeepLink")
@MainActor public func uniHandleDeepLink(_ url: UnsafePointer<CChar>) {
    let urlString = String(cString: url)
    DeeplinkHandler.handleURL(URL(string: urlString)!)
}

@MainActor
public enum DeeplinkHandler {
    public static var handleURL: (URL) -> Void = { _ in }
}
