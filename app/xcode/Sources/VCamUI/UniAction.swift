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
    init(action: @escaping () -> Void) {
        self.action = { _ in action() }
    }
}

// MARK: - Open source later

public extension UniAction {
    init(_ action: InternalUniAction<Arguments>) {
        self.action = action.action
    }
}

public struct InternalUniAction<Arguments> {
    public init(action: @escaping (Arguments) -> Void) {
        self.action = action
    }

    fileprivate let action: (Arguments) -> Void
}

public extension InternalUniAction<Void> {
    static var resetCamera = Self.init { _ in }
}

public extension InternalUniAction<String> {
    static var showEmojiStamp = Self.init { _ in }
    static var setBlendShape = Self.init { _ in }
}

public extension InternalUniAction<VCamAvatarMotion> {
    static var triggerMotion = Self.init { _ in }
}

public extension InternalUniAction<Int32> {
    static var loadScene = Self.init { _ in }
}
