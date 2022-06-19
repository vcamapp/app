//
//  NSImage+.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/06/13.
//

import AppKit
import CoreImage

extension NSImage {
    var ciImage: CIImage? {
        guard let imageData = self.tiffRepresentation else { return nil }
        return CIImage(data: imageData)
    }
}

