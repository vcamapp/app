import AppKit
import Carbon.HIToolbox
import VCamEntity

/// Hotkeys registered here fire whichever app is frontmost, without the Accessibility permission
@MainActor
final class GlobalHotKeys {
    struct RegistrationError: Error {
        let status: OSStatus
    }

    private static let signature: FourCharCode = "VCam"

    private var hotKeys: [UInt32: (ref: EventHotKeyRef, action: @MainActor () -> Void)] = [:]
    private var nextID: UInt32 = 1
    private var eventHandler: EventHandlerRef?

    func register(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, action: @escaping @MainActor () -> Void) throws {
        try installEventHandlerIfNeeded()

        let id = nextID
        nextID &+= 1
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            modifiers.carbonModifiers,
            EventHotKeyID(signature: Self.signature, id: id),
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else {
            throw RegistrationError(status: status)
        }
        hotKeys[id] = (ref, action)
    }

    func unregisterAll() {
        for hotKey in hotKeys.values {
            UnregisterEventHotKey(hotKey.ref)
        }
        hotKeys.removeAll()

        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    private func installEventHandlerIfNeeded() throws {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        // The handler is removed in unregisterAll, and the owner keeps this instance alive while hotkeys are registered
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyPressedHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        guard status == noErr else {
            throw RegistrationError(status: status)
        }
    }

    fileprivate func handle(_ hotKeyID: EventHotKeyID) -> OSStatus {
        guard hotKeyID.signature == Self.signature, let hotKey = hotKeys[hotKeyID.id] else {
            return OSStatus(eventNotHandledErr)
        }
        hotKey.action()
        return noErr
    }
}

private let hotKeyPressedHandler: EventHandlerUPP = { _, event, userData in
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }
    let hotKeys = Unmanaged<GlobalHotKeys>.fromOpaque(userData).takeUnretainedValue()
    // Events sent to the application event target are dispatched on the main thread
    return MainActor.assumeIsolated {
        hotKeys.handle(hotKeyID)
    }
}

private extension NSEvent.ModifierFlags {
    var carbonModifiers: UInt32 {
        var result = 0
        if contains(.command) { result |= cmdKey }
        if contains(.shift) { result |= shiftKey }
        if contains(.option) { result |= optionKey }
        if contains(.control) { result |= controlKey }
        return UInt32(result)
    }
}
