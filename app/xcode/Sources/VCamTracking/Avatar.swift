//
//  Avatar.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/12/30.
//

import Foundation

public class Avatar {
    public init() {}

    public var onFacialDataReceived: ((FacialData) -> Void) = { _ in }

    public func apply(_ data: FacialData) {
        onFacialDataReceived(data)
    }
}
