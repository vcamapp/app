//
//  Avatar.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/12/30.
//

import Foundation

public class Avatar {
    public init() {}

    public var onFacialDataReceived: (([Float]) -> Void) = { _ in }
    public var onHandDataReceived: (([Float]) -> Void) = { _ in }
    public var onFingerDataReceived: (([Float]) -> Void) = { _ in }

    public var oniFacialMocapReceived: ((FacialMocapData) -> Void) = { _ in }
    public var onVCamMotionReceived: ((VCamMotion) -> Void) = { _ in }
}
