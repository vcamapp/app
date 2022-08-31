//
//  FilePicker.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/05/05.
//

import AppKit
import VCamUIFoundation

@_cdecl("uniOpenFile")
public func uniOpenFile(_ fileType: Int, _ handler: @escaping @convention(c) (UnsafePointer<CChar>) -> Void) {
    guard let type = FileUtility.FileType(rawValue: fileType) else {
        handler(("" as NSString).utf8String!)
        return
    }
    if let url = FileUtility.openFile(type: type) {
        handler((url.path as NSString).utf8String!)
    } else {
        handler(("" as NSString).utf8String!)
    }
}
