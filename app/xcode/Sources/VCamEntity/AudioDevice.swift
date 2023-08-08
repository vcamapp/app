//
//  AudioDevice.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/04/24.
//

import Foundation
import struct AVFAudio.AudioDeviceID

public struct AudioDevice: Hashable, Identifiable {
    public init(id: AudioDeviceID, uid: String) {
        self.id = id
        self.uid = uid
    }

    public let id: AudioDeviceID
    public let uid: String
}
