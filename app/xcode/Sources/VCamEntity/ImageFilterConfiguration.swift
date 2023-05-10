//
//  ImageFilterConfiguration.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/06/17.
//

import Foundation

public struct ImageFilterConfiguration: Codable {
    public init(filters: [ImageFilterConfiguration.Filter]) {
        self.filters = filters
    }

    public let filters: [Filter]

    public struct Filter: Codable, Identifiable, Hashable, Equatable {
        public init(id: UUID = UUID(), type: FilterType) {
            self.id = id
            self.type = type
        }

        public var id = UUID()
        public var type: FilterType
    }

    public enum FilterType: Codable, CaseIterable, Hashable, Equatable {
        case chromaKey(ChromaKey)
        case blur(Blur)

        public static var allCases: [FilterType] = [
            .chromaKey(.init()),
            .blur(.init()),
        ]

        public struct ChromaKey: Codable, Hashable {
            public var color: VCamColor = .green
            public var threshold: Float = 0.25
        }

        public struct Blur: Codable, Hashable {
            public var radius: Float = 10
        }
    }
}
