//
//  AppStorage+.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/04/23.
//

import SwiftUI
import VCamDefaults

public extension AppStorage where Value == Bool {
    init(key: UserDefaults.Key<Value>) {
        self.init(wrappedValue: key.defaultValue, key.rawValue)
    }

    init<T: UserDefaultsValue>(key: UserDefaults.Key<T>) where Value == T.EncodeValue {
        self.init(wrappedValue: key.defaultValue.encodeUserDefaultValue(), key.rawValue)
    }
}

public extension AppStorage where Value == Int {
    init(key: UserDefaults.Key<Value>) {
        self.init(wrappedValue: key.defaultValue, key.rawValue)
    }

    init<T: UserDefaultsValue>(key: UserDefaults.Key<T>) where Value == T.EncodeValue {
        self.init(wrappedValue: key.defaultValue.encodeUserDefaultValue(), key.rawValue)
    }
}

public extension AppStorage where Value == String {
    init(key: UserDefaults.Key<Value>) {
        self.init(wrappedValue: key.defaultValue, key.rawValue)
    }

    init<T: UserDefaultsValue>(key: UserDefaults.Key<T>) where Value == T.EncodeValue {
        self.init(wrappedValue: key.defaultValue.encodeUserDefaultValue(), key.rawValue)
    }
}

public extension AppStorage where Value == Double {
    init(key: UserDefaults.Key<Value>) {
        self.init(wrappedValue: key.defaultValue, key.rawValue)
    }

    init<T: UserDefaultsValue>(key: UserDefaults.Key<T>) where Value == T.EncodeValue {
        self.init(wrappedValue: key.defaultValue.encodeUserDefaultValue(), key.rawValue)
    }
}

public extension AppStorage where Value == Data {
    init(key: UserDefaults.Key<Value>) {
        self.init(wrappedValue: key.defaultValue, key.rawValue)
    }

    init<T: UserDefaultsValue>(key: UserDefaults.Key<T>) where Value == T.EncodeValue {
        self.init(wrappedValue: key.defaultValue.encodeUserDefaultValue(), key.rawValue)
    }
}
