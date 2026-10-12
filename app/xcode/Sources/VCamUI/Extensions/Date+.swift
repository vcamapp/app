//
//  Date+.swift
//
//
//  Created by Tatsuya Tanaka on 2022/04/19.
//

import Foundation

public extension Date {
    /// Used in file names, so the user's calendar (e.g. Japanese era years) must not change the digits
    var yyyyMMddHHmmss: String {
        formatted(.verbatim(
            "\(year: .padded(4))\(month: .twoDigits)\(day: .twoDigits)\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased))\(minute: .twoDigits)\(second: .twoDigits)",
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: .current,
            calendar: Calendar(identifier: .gregorian)
        ))
    }
}
