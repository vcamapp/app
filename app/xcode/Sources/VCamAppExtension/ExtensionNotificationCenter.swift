import Foundation
import os

public enum ExtensionNotification: String, Equatable, Sendable {
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

public final class ExtensionNotificationCenter: Sendable {
    public static let `default` = ExtensionNotificationCenter()

    private nonisolated(unsafe) let center = CFNotificationCenterGetDarwinNotifyCenter()
    private let observers = OSAllocatedUnfairLock(initialState: [ExtensionNotification: @Sendable () -> Void]())

    public func post(_ notification: ExtensionNotification) {
        CFNotificationCenterPostNotification(
            center,
            notification.cfNotificationName,
            nil,
            nil,
            true
        )
    }

    public func setObserver(for notification: ExtensionNotification, using: @escaping @Sendable () -> Void) {
        let alreadyRegistered = observers.withLock { observers in
            let exists = observers.keys.contains(notification)
            observers[notification] = using
            return exists
        }

        guard !alreadyRegistered else { return }

        let observer = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CFNotificationCenterAddObserver(
            center,
            observer,
            { _, observer, name, _, _ in
                if let observer = observer, let name = name, let notification = ExtensionNotification(name: name) {
                    let observerSelf = Unmanaged<ExtensionNotificationCenter>.fromOpaque(observer).takeUnretainedValue()
                    observerSelf.observers.withLock { $0[notification]?() }
                }
            },
            notification.rawValue as CFString,
            nil,
            .deliverImmediately
        )
    }

    public func removeAllObservers() {
        observers.withLock { $0.removeAll() }
        CFNotificationCenterRemoveEveryObserver(center, Unmanaged.passRetained(self).toOpaque())
    }
}
