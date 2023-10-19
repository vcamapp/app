//
//  UniBridge+ExternalStateBinding.swift
//
//
//  Created by Tatsuya Tanaka on 2023/4/14.
//

import Foundation

private let baseUUID = UUID().uuid

public extension UUID {
    static func externalState<T: RawRepresentable>(_ keyPath: WritableKeyPath<uuid_t, UInt8>, type: T) -> UUID where T.RawValue == Int32 {
        var uuid = baseUUID
        uuid[keyPath: keyPath] = UInt8(type.rawValue)
        return UUID(uuid: uuid)
    }
}

public extension ExternalStateBinding {
    init(_ type: UniBridge.BoolType) where Value == Bool {
        let mapper = UniBridge.shared.boolMapper
        self.init(id: .externalState(\.0, type: type), get: { mapper.get(type) }, set: mapper.set(type))
    }

    init(_ type: UniBridge.FloatType) where Value == CGFloat {
        let mapper = UniBridge.shared.floatMapper
        self.init(id: .externalState(\.1, type: type), get: { mapper.get(type) }, set: mapper.set(type))
    }

    init(_ type: UniBridge.IntType) where Value == Int32 {
        let mapper = UniBridge.shared.intMapper
        self.init(id: .externalState(\.2, type: type), get: { mapper.get(type) }, set: mapper.set(type))
    }

    init(_ type: UniBridge.StringType) where Value == String {
        let mapper = UniBridge.shared.stringMapper
        self.init(id: .externalState(\.3, type: type), get: { mapper.get(type) }, set: mapper.set(type))
    }

    init<Element>(_ type: UniBridge.ArrayType, as: Array<Element>.Type) where Value == Array<Element> {
        let mapper = UniBridge.shared.arrayMapper
        self.init(id: .externalState(\.4, type: type), get: { mapper.binding(type, size: type.arraySize).wrappedValue }, set: mapper.set(type))
    }

    init(_ type: UniBridge.StructType, as: Value.Type = Value.self) where Value: ValueBindingStructType {
        let mapper = UniBridge.shared.structMapper
        self.init(id: .externalState(\.5, type: type), get: { mapper.binding(type).wrappedValue }, set: { mapper.binding(type).wrappedValue = $0 })
    }
}
