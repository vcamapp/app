//
//  CoreMediaIO+.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/02/16.
//

import Foundation
import CoreMediaIO

public extension CMIOObjectPropertyScope {
    static let global = Self.init(kCMIOObjectPropertyScopeGlobal)
}

public extension CMIOObjectPropertyElement {
    static let main = Self.init(kCMIOObjectPropertyElementMain)
}

public extension CMIOObjectPropertySelector {
    static let systemObject = Self.init(kCMIOObjectSystemObject)
    static let hardwarePropertyDevices = Self.init(kCMIOHardwarePropertyDevices)
    static let deviceUID = Self.init(kCMIODevicePropertyDeviceUID)
    static let devicePropertyStreams = Self.init(kCMIODevicePropertyStreams)
}
