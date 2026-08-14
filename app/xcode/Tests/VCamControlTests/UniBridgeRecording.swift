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

/// Records loadVRM calls and completes each one with `errorCode`, standing in for the engine
@MainActor
func completingModelLoads(errorCode: Int32, during body: () async throws -> Void) async rethrows -> [LoadVRMCall] {
    nonisolated(unsafe) var calls: [LoadVRMCall] = []
    let originalCallback = UniBridge.methodCallback
    defer {
        UniBridge.methodCallback = originalCallback
    }
    UniBridge.methodCallback = { method, payload, _ in
        guard let call = LoadVRMCall(method: method, payload: payload) else { return }
        calls.append(call)
        guard let requestID = call.requestID else { return }
        Task { @MainActor in
            UniRequestHub.modelLoad.complete(requestID: requestID, errorCode: errorCode)
        }
    }
    try await body()
    return calls
}
