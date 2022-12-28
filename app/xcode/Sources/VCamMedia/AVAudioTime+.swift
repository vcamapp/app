//
//  AVAudioTime+.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/12/29.
//

import AVFAudio

public extension AVAudioTime {
    func timeIntervalSince(hostTime: UInt64 = mach_absolute_time()) -> TimeInterval {
        let baseTime = AVAudioTime.seconds(forHostTime: hostTime)
        let currenTime = AVAudioTime.seconds(forHostTime: self.hostTime)
        return currenTime - baseTime
    }
}
