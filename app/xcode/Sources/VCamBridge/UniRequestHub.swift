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
        mapErrorCode: { VrmaMotionError(code: $0) }
    )
    // Importing a large model takes a while, hence the long timeout
    public static let modelLoad = UniRequestHub(
        timeout: .seconds(120),
        timeoutError: ModelLoadError.timedOut,
        mapErrorCode: { ModelLoadError(code: $0) }
    )

    private struct PendingRequest {
        let continuation: CheckedContinuation<Void, any Error>
        let timeoutTask: Task<Void, Never>
    }

    private let timeout: Duration
    private let timeoutError: any Error
    private let mapErrorCode: @Sendable (Int32) -> any Error
    private var requests: [UUID: PendingRequest] = [:]

    private init(timeout: Duration, timeoutError: any Error, mapErrorCode: @escaping @Sendable (Int32) -> any Error) {
        self.timeout = timeout
        self.timeoutError = timeoutError
        self.mapErrorCode = mapErrorCode
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
}
