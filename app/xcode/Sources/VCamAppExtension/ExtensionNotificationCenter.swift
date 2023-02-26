//
//  ExtensionNotificationCenter.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/02/25.
//

import Foundation

public enum ExtensionNotification: String, Equatable {
    case startCameraExtensionStream
    case stopAllCameraExtensionStreams

    init?(name: CFNotificationName) {
        guard let notification = ExtensionNotification(rawValue: name.rawValue as String) else {
            return nil
        }
        self = notification
    }

    var cfNotificationName: CFNotificationName {
        CFNotificationName(rawValue as NSString)
    }
}

public final class ExtensionNotificationCenter {
    public static let `default` = ExtensionNotificationCenter()

    private let center = CFNotificationCenterGetDarwinNotifyCenter()
    private var observers: [ExtensionNotification: () -> Void] = [:]

    public func post(_ notification: ExtensionNotification) {
        CFNotificationCenterPostNotification(
            center,
            notification.cfNotificationName,
            nil,
            nil,
            true
        )
    }

    public func setObserver(for notification: ExtensionNotification, using: @escaping () -> Void) {
        defer {
            observers[notification] = using
        }

        guard !observers.keys.contains(notification) else {
            return
        }

        let observer = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CFNotificationCenterAddObserver(
            center,
            observer,
            { _, observer, name, _, _ in
                if let observer = observer, let name = name, let notification = ExtensionNotification(name: name) {
                    let observerSelf = Unmanaged<ExtensionNotificationCenter>.fromOpaque(observer).takeUnretainedValue()
                    observerSelf.observers[notification]?()
                }
            },
            notification.rawValue as CFString,
            nil,
            .deliverImmediately
        )
    }

    public func removeAllObservers() {
        observers.removeAll()
        CFNotificationCenterRemoveEveryObserver(center, Unmanaged.passRetained(self).toOpaque())
    }
}
