//
//  UniAction.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/03/24.
//

import Foundation
import VCamEntity

@propertyWrapper public struct UniAction<Arguments>: Equatable {
    public init(action: @escaping (Arguments) -> Void) {
        self.action = action
    }

    private let action: (Arguments) -> Void

    public var wrappedValue: Action {
        .init(action: action)
    }

    public struct Action {
        let action: (Arguments) -> Void

        public func callAsFunction(_ arguments: Arguments) {
            action(arguments)
        }
    }

    public static func == (lhs: UniAction<Arguments>, rhs: UniAction<Arguments>) -> Bool {
        true
    }
}

public extension UniAction<Void>.Action {
    func callAsFunction() {
        action(())
    }
}

public extension UniAction<Void> {
    init(_ type: UniBridge.TriggerType) {
        let mapper = UniBridge.shared.triggerMapper
        self.init(action: mapper.trigger(type))
    }
}

public extension UniAction<String> {
    init(_ type: UniBridge.StringType) {
        let mapper = UniBridge.shared.stringMapper
        self.init(action: mapper.set(type))
    }
}
