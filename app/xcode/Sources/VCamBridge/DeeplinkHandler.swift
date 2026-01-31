import Foundation

@MainActor
public enum DeeplinkHandler {
    public static var handleURL: (URL) -> Void = { _ in }
}
