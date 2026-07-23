import Foundation
import VCamEntity

public enum MotionImportError: Error {
    case registrationTimedOut
}

/// Associates asynchronous requests to Unity with their completion notifications.
/// Use the async bridge APIs (e.g. UniBridge.registerImportedMotion) instead of calling this directly
@MainActor
public final class MotionRegistrationHub {
    public static let shared = MotionRegistrationHub()

    private struct PendingRequest {
        let continuation: CheckedContinuation<Void, any Error>
        let timeoutTask: Task<Void, Never>
    }

    private var requests: [UUID: PendingRequest] = [:]

    private init() {}

    func wait(requestID: UUID, timeout: Duration = .seconds(15), start: () -> Void) async throws {
        try Task.checkCancellation()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let timeoutTask = Task { [weak self] in
                    try? await Task.sleep(for: timeout)
                    guard !Task.isCancelled else { return }
                    self?.resume(requestID: requestID, result: .failure(MotionImportError.registrationTimedOut))
                }
                requests[requestID] = PendingRequest(continuation: continuation, timeoutTask: timeoutTask)
                start()
            }
        } onCancel: {
            // Cancelling the parent task must not leave the continuation waiting for Unity or the timeout
            Task { @MainActor in
                MotionRegistrationHub.shared.resume(requestID: requestID, result: .failure(CancellationError()))
            }
        }
    }

    /// Completion notification from Unity (an errorCode of 0 means success)
    public func complete(requestID: UUID, errorCode: Int32) {
        if errorCode == 0 {
            resume(requestID: requestID, result: .success(()))
        } else {
            resume(requestID: requestID, result: .failure(VrmaMotionError(code: errorCode)))
        }
    }

    private func resume(requestID: UUID, result: Result<Void, any Error>) {
        guard let request = requests.removeValue(forKey: requestID) else { return }
        request.timeoutTask.cancel()
        request.continuation.resume(with: result)
    }
}

public extension UniBridge {
    /// Registers a VRMA to Unity and waits for the validation result
    @MainActor
    static func registerImportedMotion(id: String, path: String, axisMask: UInt8, loadImmediately: Bool) async throws {
        let requestID = UUID()
        try await MotionRegistrationHub.shared.wait(requestID: requestID) {
            registerImportedMotion(id: id, path: path, axisMask: axisMask, loadImmediately: loadImmediately, requestID: requestID)
        }
    }
}
