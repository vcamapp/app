//
//  AVAudioTime+.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/12/29.
//

import AVFAudio

public extension AVAudioTime {
    func timeIntervalSince(hostTime: UInt64 = mach_absolute_time()) -> TimeInterval {
        Self.timeInterval(currentTime: self.hostTime, since: hostTime)
    }

    static func timeInterval(currentTime: UInt64, since baseTime: UInt64) -> TimeInterval {
        let baseTimeSeconds = AVAudioTime.seconds(forHostTime: baseTime)
        let currenTimeSeconds = AVAudioTime.seconds(forHostTime: currentTime)
        return currenTimeSeconds - baseTimeSeconds
    }
}
