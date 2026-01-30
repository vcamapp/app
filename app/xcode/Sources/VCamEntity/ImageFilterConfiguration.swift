//
//  ImageFilterConfiguration.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/06/17.
//

import Foundation

public struct ImageFilterConfiguration: Codable, Sendable {
    public init(filters: [ImageFilterConfiguration.Filter]) {
        self.filters = filters
    }

    public let filters: [Filter]

    public struct Filter: Codable, Identifiable, Hashable, Equatable, Sendable {
        public init(id: UUID = UUID(), type: FilterType) {
            self.id = id
            self.type = type
        }

        public var id = UUID()
        public var type: FilterType
    }

    public enum FilterType: Codable, CaseIterable, Hashable, Equatable, Sendable {
        case chromaKey(ChromaKey)
        case blur(Blur)

        public static var allCases: [FilterType] {
            [
                .chromaKey(.init()),
                .blur(.init()),
            ]
        }

        public struct ChromaKey: Codable, Hashable, Sendable {
            public var color: VCamColor = .green
            public var threshold: Float = 0.25
        }

        public struct Blur: Codable, Hashable, Sendable {
            public var radius: Float = 10
        }
    }
}
