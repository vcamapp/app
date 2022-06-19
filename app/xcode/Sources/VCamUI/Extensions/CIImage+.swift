//
//  CIImage+.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/06/13.
//

import CoreImage
import AppKit

extension CIImage {
    func nsImage() -> NSImage {
        let rep = NSCIImageRep(ciImage: self)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }
}
