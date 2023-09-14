//
//  Version.swift
//  Version
//
//  Created by Tatsuya Tanaka on 2017/04/14.
//  Copyright © 2017 tattn. All rights reserved.
//
import Foundation

public struct Version {
    public let components: [Int]

    static var bundle: Bundle = .main

    public init() {
        components = []
    }

    public init?(version: String) {
        let separatedStrings = version.components(separatedBy: ".")
        components = separatedStrings.compactMap { Int($0) }

        // parse check
        guard !isEmpty, separatedStrings.count == count else {
            return nil
        }
    }
}

extension Version {
    public static var current: Version {
        guard let versionString = bundle.infoDictionary?["CFBundleShortVersionString"] as? String,
            let version = Version(version: versionString) else {
                fatalError("CFBundleShortVersionString is not a valid version string")
        }
        return version
    }

    public static var currentBuildNumber: Version {
        guard let versionString = bundle.infoDictionary?["CFBundleVersion"] as? String,
            let version = Version(version: versionString) else {
                fatalError("CFBundleVersion is not a valid version string")
        }
        return version
    }
}

extension Version: Hashable {
    public func hash(into hasher: inout Hasher) {
        let values: [Int] = components.reversed().reduce(into: []) { result, value in
            if value == 0, result.isEmpty { return }
            result.append(value)
        }
        for component in values.reversed() {
            component.hash(into: &hasher)
        }
    }
}

extension Version: Equatable {
    public static func == (lhs: Version, rhs: Version) -> Bool {
        return !zip(lhs, rhs).contains { $0 != $1 }
    }
}

extension Version: Comparable {
    public static func < (lhs: Version, rhs: Version) -> Bool {
        let maxLength = Swift.max(lhs.count, rhs.count)
        for index in (0...maxLength) {
            let left = lhs.count > index ? lhs[index] : 0
            let right = rhs.count > index ? rhs[index] : 0
            if left != right {
                return left < right
            }
        }

        return false
    }
}

extension Version: CustomStringConvertible {
    public var description: String {
        return components.map(String.init).joined(separator: ".")
    }
}

extension Version: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        guard let version = Version(version: value) else {
            fatalError("\(value) is not a valid version")
        }
        self = version
    }

    public init(extendedGraphemeClusterLiteral value: String) {
        self.init(stringLiteral: value)
    }

    public init(unicodeScalarLiteral value: String) {
        self.init(stringLiteral: value)
    }
}

extension Version: Collection {
    public var startIndex: Int { return 0 }
    public var endIndex: Int { return components.count }

    public subscript (index: Int) -> Int {
        return components[index]
    }

    public func index(after index: Index) -> Int {
        return index + 1
    }
}

extension Version: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard let version = Version(version: value) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid string")
        }
        self = version
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
