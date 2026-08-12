import Foundation
@testable import VCamBridge

// Swaps the UniBridge hooks for recording closures and restores them after `body` runs.

@MainActor
func recordedMethodCalls<Call>(_ decode: @escaping (UniBridgeMethodId, UnsafeMutableRawPointer?) -> Call?, during body: () -> Void) -> [Call] {
    var calls: [Call] = []
    let originalCallback = UniBridge.methodCallback
    defer {
        UniBridge.methodCallback = originalCallback
    }
    UniBridge.methodCallback = { method, payload, _ in
        if let call = decode(method, payload) {
            calls.append(call)
        }
    }
    body()
    return calls
}

@MainActor
func recordedTriggers(during body: () -> Void) -> [UniBridge.TriggerType] {
    var triggered: [UniBridge.TriggerType] = []
    let mapper = UniBridge.shared.triggerMapper
    let originalGetValue = mapper.getValue
    defer {
        mapper.getValue = originalGetValue
    }
    mapper.getValue = { triggered.append($0) }
    body()
    return triggered
}

@MainActor
func recordedStringValues(during body: () -> Void) -> [(type: UniBridge.StringType, value: String)] {
    var values: [(type: UniBridge.StringType, value: String)] = []
    let mapper = UniBridge.shared.stringMapper
    let originalSetValue = mapper.setValue
    defer {
        mapper.setValue = originalSetValue
    }
    mapper.setValue = { values.append((type: $0, value: $1)) }
    body()
    return values
}
