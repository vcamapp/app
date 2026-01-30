import AppKit
import VCamUIFoundation

@_cdecl("uniOpenFile")
@MainActor public func uniOpenFile(_ fileType: Int, _ handler: @escaping @Sendable @convention(c) (UnsafePointer<CChar>) -> Void) {
    guard let type = FileUtility.FileType(rawValue: fileType) else {
        handler(("" as NSString).utf8String!)
        return
    }
    let path = FileUtility.openFile(type: type)?.path ?? ""
    handler((path as NSString).utf8String!)
}
