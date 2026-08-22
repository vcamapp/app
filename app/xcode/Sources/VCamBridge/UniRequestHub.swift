import Foundation
import VCamEntity

public enum MotionImportError: Error {
    case registrationTimedOut
}

/// Associates asynchronous requests to the engine with their completion notifications.
/// Use the async bridge APIs (e.g. UniBridge.registerImportedMotion) instead of calling this directly
@MainActor
public final class UniRequestHub {
    public static let motionRegistration = UniRequestHub(
        timeout: .seconds(15),
        timeoutError: MotionImportError.registrationTimedOut,
        errorType: VrmaMotionError.self
    )
    // Importing a large model takes a while, hence the long timeout
    public static let modelLoad = UniRequestHub(
        timeout: .seconds(120),
        timeoutError: ModelLoadError.timedOut,
        errorType: ModelLoadError.self
    )
    public static let accessoryApply = UniRequestHub(
        timeout: .seconds(60),
        timeoutError: AccessoryApplyError.timedOut,
        errorType: AccessoryApplyError.self
    )

    private struct PendingRequest {
        let continuation: CheckedContinuation<Void, any Error>
        let timeoutTask: Task<Void, Never>
    }

    private let timeout: Duration
    private let timeoutError: any Error
    private let mapErrorCode: @Sendable (Int32) -> any Error
    private var requests: [UUID: PendingRequest] = [:]

    private init<E: EngineResultError>(timeout: Duration, timeoutError: any Error, errorType: E.Type) {
        self.timeout = timeout
        self.timeoutError = timeoutError
        mapErrorCode = { E(code: $0) }
    }

    func wait(requestID: UUID, start: () -> Void) async throws {
        try Task.checkCancellation()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let timeoutTask = Task { [weak self, timeout, timeoutError] in
                    try? await Task.sleep(for: timeout)
                    guard !Task.isCancelled else { return }
                    self?.resume(requestID: requestID, result: .failure(timeoutError))
                }
                requests[requestID] = PendingRequest(continuation: continuation, timeoutTask: timeoutTask)
                guard !Task.isCancelled else {
                    resume(requestID: requestID, result: .failure(CancellationError()))
                    return
                }
                start()
            }
        } onCancel: {
            // Cancelling the parent task must not leave the continuation waiting for the engine or the timeout
            Task { @MainActor [weak self] in
                self?.resume(requestID: requestID, result: .failure(CancellationError()))
            }
        }
    }

    /// Completion notification from the engine (an errorCode of 0 means success)
    public func complete(requestID: UUID, errorCode: Int32) {
        if errorCode == 0 {
            resume(requestID: requestID, result: .success(()))
        } else {
            resume(requestID: requestID, result: .failure(mapErrorCode(errorCode)))
        }
    }

    private func resume(requestID: UUID, result: Result<Void, any Error>) {
        guard let request = requests.removeValue(forKey: requestID) else { return }
        request.timeoutTask.cancel()
        request.continuation.resume(with: result)
    }
}

extension UniBridge {
    /// Decodes the request identifier carried by an asynchronous bridge method.
    @MainActor
    package static func completeRequest(
        method: UniBridgeMethodId,
        payload: UnsafeMutableRawPointer?,
        errorCode: Int32
    ) {
        guard let payload else { return }

        let request: (hub: UniRequestHub, idPointer: UnsafePointer<CChar>?)
        switch method {
        case .registerImportedMotion:
            let call = payload.assumingMemoryBound(to: RegisterImportedMotionPayload.self).pointee
            request = (.motionRegistration, call.requestIDPtr)
        case .loadVRM:
            let call = payload.assumingMemoryBound(to: LoadVRMPayload.self).pointee
            request = (.modelLoad, call.requestIDPtr)
        case .applyAccessoryPlacements:
            let call = payload.assumingMemoryBound(to: ApplyAccessoryPlacementsPayload.self).pointee
            request = (.accessoryApply, call.requestIDPtr)
        default:
            return
        }

        guard let idPointer = request.idPointer,
              let requestID = UUID(uuidString: String(cString: idPointer)) else { return }
        request.hub.complete(requestID: requestID, errorCode: errorCode)
    }
}

public extension UniBridge {
    /// Registers a VRMA to the engine and waits for the validation result
    @MainActor
    static func registerImportedMotion(id: String, path: String, axisMask: UInt8, loadImmediately: Bool) async throws {
        let requestID = UUID()
        try await UniRequestHub.motionRegistration.wait(requestID: requestID) {
            registerImportedMotion(id: id, path: path, axisMask: axisMask, loadImmediately: loadImmediately, requestID: requestID)
        }
    }

    /// Loads a VRM into the current scene and waits for the load result.
    /// The engine rejects loads while a scene transition is in flight, which is
    /// expected right after launch, so a short retry covers that window
    @MainActor
    static func loadVRM(path: String, source: VRMLoadSource, retryCount: Int = 2) async throws {
        for attempt in 0...retryCount {
            do {
                let requestID = UUID()
                return try await UniRequestHub.modelLoad.wait(requestID: requestID) {
                    loadVRM(path: path, source: source, requestID: requestID)
                }
            } catch ModelLoadError.notReady where attempt < retryCount {
                try await Task.sleep(for: .seconds(2))
            }
        }
    }

    /// Applies the accessory placements to the live avatar and waits for the result.
    /// The list is the full set of placements: accessories the engine holds but
    /// the list does not reference are removed
    @MainActor
    static func applyAccessoryPlacements(_ placements: [AccessoryPlacement]) async throws {
        let json = try AccessoryPlacement.encode(placements)
        let requestID = UUID()
        try await UniRequestHub.accessoryApply.wait(requestID: requestID) {
            applyAccessoryPlacements(json: json, requestID: requestID)
        }
    }
}
