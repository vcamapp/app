//
//  UniBridge+ExternalStateBinding.swift
//
//
//  Created by Tatsuya Tanaka on 2023/4/14.
//

import Foundation

private let baseUUID = UUID()

public extension ExternalStateBinding {
    init(_ type: UniBridge.BoolType) where Value == Bool {
        var uuid = baseUUID.uuid
        uuid.0 = UInt8(type.rawValue)
        let mapper = UniBridge.shared.boolMapper
        self.init(id: UUID(uuid: uuid), get: { mapper.get(type) }, set: mapper.set(type))
    }
}
