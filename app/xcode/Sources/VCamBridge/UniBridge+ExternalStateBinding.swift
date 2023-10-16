//
//  UniBridge+ExternalStateBinding.swift
//
//
//  Created by Tatsuya Tanaka on 2023/4/14.
//

import Foundation

private let baseUUID = UUID().uuid

private func uuid(_ keyPath: WritableKeyPath<uuid_t, UInt8>, typeValue: Int32) -> UUID {
    var uuid = baseUUID
    uuid[keyPath: keyPath] = UInt8(typeValue)
    return UUID(uuid: uuid)
}

public extension ExternalStateBinding {
    init(_ type: UniBridge.BoolType) where Value == Bool {
        let mapper = UniBridge.shared.boolMapper
        self.init(id: uuid(\.0, typeValue: type.rawValue), get: { mapper.get(type) }, set: mapper.set(type))
    }

    init(_ type: UniBridge.FloatType) where Value == CGFloat {
        let mapper = UniBridge.shared.floatMapper
        self.init(id: uuid(\.1, typeValue: type.rawValue), get: { mapper.get(type) }, set: mapper.set(type))
    }

    init(_ type: UniBridge.IntType) where Value == Int32 {
        let mapper = UniBridge.shared.intMapper
        self.init(id: uuid(\.2, typeValue: type.rawValue), get: { mapper.get(type) }, set: mapper.set(type))
    }

    init(_ type: UniBridge.StringType) where Value == String {
        let mapper = UniBridge.shared.stringMapper
        self.init(id: uuid(\.3, typeValue: type.rawValue), get: { mapper.get(type) }, set: mapper.set(type))
    }

    init<Element>(_ type: UniBridge.ArrayType, as: Array<Element>.Type) where Value == Array<Element> {
        let mapper = UniBridge.shared.arrayMapper
        self.init(id: uuid(\.4, typeValue: type.rawValue), get: { mapper.binding(type, size: type.arraySize).wrappedValue }, set: mapper.set(type))
    }

    init(_ type: UniBridge.StructType, as: Value.Type = Value.self) where Value: ValueBindingStructType {
        let mapper = UniBridge.shared.structMapper
        self.init(id: uuid(\.5, typeValue: type.rawValue), get: { mapper.binding(type).wrappedValue }, set: { mapper.binding(type).wrappedValue = $0 })
    }
}
