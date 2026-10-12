import Foundation

extension FileManager {
    public func createDirectoryIfNeeded(at url: URL) throws {
        if !fileExists(atPath: url.path(percentEncoded: false)) {
            try createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
