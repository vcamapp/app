//
//  Version+UserDefaultsValue.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/04/23.
//

import Foundation
import VCamEntity
import VCamDefaults

extension Version: UserDefaultsValue {
    public func encodeUserDefaultValue() -> String {
        description
    }

    public static func decodeUserDefaultValue(_ value: String) -> Version? {
        Version(version: value)
    }
}
