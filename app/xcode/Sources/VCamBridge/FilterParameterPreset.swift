//
//  FilterParameterPreset.swift
//
//
//  Created by Tatsuya Tanaka on 2022/03/22.
//

import Foundation
import VCamLocalization

public struct FilterParameterPreset: CaseIterable, Hashable, Identifiable, CustomStringConvertible {
    public static var allCases: [FilterParameterPreset] {
        let params = UniBridge.shared.allDisplayParameterPresets.components(separatedBy: ",")
        return params.compactMap {
            let values = $0.components(separatedBy: "@")
            guard values.count == 2 else { return nil }
            return FilterParameterPreset(id: values[0], description: values[1])
        }
    }

    public static let newPreset = Self.init(id: "", description: L10n.newPreset.text)

    public let id: String
    public var description: String
}

extension FilterParameterPreset {
    public init(string: String) {
        let values = string.components(separatedBy: "@")
        if values.count == 2 {
            self = FilterParameterPreset(id: values[0], description: values[1])
        } else {
            self = .newPreset
        }
    }
}

private let currentFilterParameterPresetId = UUID()

public extension ExternalState {
    static var currentFilterParameterPreset: ExternalState<FilterParameterPreset> {
        .init(id: currentFilterParameterPresetId) {
            FilterParameterPreset(string: UniBridge.shared.currentDisplayParameter.wrappedValue)
        } set: {
            UniBridge.shared.currentDisplayParameter.wrappedValue = "\($0.id)@\($0.description)"
            UniBridge.shared.applyDisplayParameter()
        }
    }
}
