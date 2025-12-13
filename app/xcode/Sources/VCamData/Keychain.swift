//
//  Keychain.swift
//  
//
//  Created by Tatsuya Tanaka on 2025/11/15.
//

import Foundation
import Security

public enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)
    case notFound
    case invalidData

    public var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to Keychain: \(status)"
        case .loadFailed(let status):
            return "Failed to load from Keychain: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete from Keychain: \(status)"
        case .notFound:
            return "Item not found in Keychain"
        case .invalidData:
            return "Invalid data format in Keychain"
        }
    }
}

public struct Keychain {
    private let accessGroup: String

    public init(accessGroup: String) {
        self.accessGroup = accessGroup
    }

    // MARK: - Save

    public func save(_ value: String, forKey key: Key<String>) throws(KeychainError) {
        try saveData(Data(value.utf8), rawKey: key.rawValue)
    }

    public func save(_ data: Data, forKey key: Key<Data>) throws(KeychainError) {
        try saveData(data, rawKey: key.rawValue)
    }

    private func saveData(_ data: Data, rawKey: String) throws(KeychainError) {
        // Delete existing item first
        try? delete(rawKey: rawKey)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: rawKey,
            kSecAttrAccessGroup as String: accessGroup,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecUseDataProtectionKeychain as String: true,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw .saveFailed(status)
        }
    }

    // MARK: - Load

    public func loadString(forKey key: Key<String>) throws(KeychainError) -> String {
        let data = try loadData(rawKey: key.rawValue)
        return String(decoding: data, as: UTF8.self)
    }

    public func load(forKey key: Key<Data>) throws(KeychainError) -> Data {
        try loadData(rawKey: key.rawValue)
    }

    private func loadData(rawKey: String) throws(KeychainError) -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: rawKey,
            kSecAttrAccessGroup as String: accessGroup,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw .notFound
            }
            throw .loadFailed(status)
        }

        guard let data = item as? Data else {
            throw .invalidData
        }

        return data
    }

    // MARK: - Delete

    public func delete<T>(forKey key: Key<T>) throws(KeychainError) {
        try delete(rawKey: key.rawValue)
    }

    private func delete(rawKey: String) throws(KeychainError) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: rawKey,
            kSecAttrAccessGroup as String: accessGroup,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw .deleteFailed(status)
        }
    }

    // MARK: - Exists

    public func exists<T>(forKey key: Key<T>) -> Bool {
        exists(rawKey: key.rawValue)
    }

    private func exists(rawKey: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: rawKey,
            kSecAttrAccessGroup as String: accessGroup,
            kSecReturnData as String: false,
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}

// MARK: - Key

public extension Keychain {
    struct Key<Value> {
        public let rawValue: String

        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }
    }
}
