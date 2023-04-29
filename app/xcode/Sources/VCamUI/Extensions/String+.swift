//
//  String+.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/03/22.
//

import AppKit

public extension String {
    func drawImage() -> NSImage {
        let nsString = self as NSString
        let font = NSFont.systemFont(ofSize: 512)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let imageSize = nsString.size(withAttributes: attributes)

        let image = NSImage(size: imageSize)
        image.lockFocus()
        nsString.draw(at: .zero, withAttributes: attributes)
        image.unlockFocus()
        return image
    }
}

extension String: Identifiable {
    public var id: Self { self }
}
