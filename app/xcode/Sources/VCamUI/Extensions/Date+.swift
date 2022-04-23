//
//  Date+.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/04/19.
//

import Foundation

public extension Date {
    var yyyyMMddHHmmss: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        return formatter.string(from: Date())
    }
}
