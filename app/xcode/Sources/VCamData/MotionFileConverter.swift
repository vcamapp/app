import Foundation

/// Turns a motion file of another format into VRMA when it is imported, so that the engine and the library only deal with VRMA
public struct MotionFileConverter: Sendable {
    public let fileExtension: String
    /// Shown in the import window, e.g. to remind the user to check how the file may be used
    public let importNote: String?
    public let convert: @Sendable (_ data: Data, _ name: String) throws -> Data

    public init(fileExtension: String, importNote: String?, convert: @escaping @Sendable (_ data: Data, _ name: String) throws -> Data) {
        self.fileExtension = fileExtension
        self.importNote = importNote
        self.convert = convert
    }
}

/// Thrown by `MotionFileConverter.convert` when the file is readable but cannot be used as a motion
public struct MotionFileConversionError: Error {
    public let message: String

    public init(message: String) {
        self.message = message
    }
}
