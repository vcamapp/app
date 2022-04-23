//
//  AppStorage+.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/04/23.
//

import SwiftUI

extension AppStorage {
    init(key: UserDefaults.Key<Bool>) where Value == Bool? {
        self.init(key.rawValue)
    }
}

extension AppStorage {
    init(key: UserDefaults.Key<Int>) where Value == Int? {
        self.init(key.rawValue)
    }
}

extension AppStorage {
    init(key: UserDefaults.Key<String>) where Value == String? {
        self.init(key.rawValue)
    }
}

extension AppStorage {
    init<T: UserDefaultsValue>(key: UserDefaults.Key<T>) where Value == T.EncodeValue?, Value == Bool? {
        self.init(key.rawValue)
    }
}

extension AppStorage {
    init<T: UserDefaultsValue>(key: UserDefaults.Key<T>) where Value == T.EncodeValue?, Value == Int? {
        self.init(key.rawValue)
    }
}

extension AppStorage {
    init<T: UserDefaultsValue>(key: UserDefaults.Key<T>) where Value == T.EncodeValue?, Value == String? {
        self.init(key.rawValue)
    }
}
