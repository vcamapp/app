//
//  AVCaptureDevice+.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/04/14.
//

import AVFoundation

extension AVCaptureDevice: Identifiable {
    public var id: String {
        self.uniqueID
    }
}
