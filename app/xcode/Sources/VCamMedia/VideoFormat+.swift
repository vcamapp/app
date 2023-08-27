//
//  VideoFormat+.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/04/22.
//

import VCamEntity
import AVFoundation

public extension VideoFormat {
    var fileType: AVFileType {
        switch self {
        case .mp4:
            return .mp4
        case .mov:
            return .mov
        case .m4v:
            return .m4v
        }
    }
}
