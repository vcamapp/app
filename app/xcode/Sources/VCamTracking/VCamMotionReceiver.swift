import Network
import Observation
import VCamLogger

@Observable
public final class VCamMotionReceiver: @unchecked Sendable { // TODO: Fix Sendable conformance
    private static let queue = DispatchQueue(label: "com.github.tattn.vcam.vcammotionreceiver")
    @ObservationIgnored private var listener: NWListener?
    @ObservationIgnored private var connection: NWConnection?
    @ObservationIgnored private weak var tracking: VCamMotionTracking?

    @MainActor public private(set) var connectionStatus = ConnectionStatus.disconnected

    @ObservationIgnored private var shouldAutoReconnect = true
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?

    private static let dataTimeoutSeconds: UInt64 = 2

    public enum Error: Swift.Error {
        case cancelled
    }

    public init() {}

    @MainActor
    func start(with tracking: VCamMotionTracking) async throws {
        Logger.log("\(listener == nil)")
        guard listener == nil else { return }

        self.tracking = tracking
        shouldAutoReconnect = true
        connectionStatus = .connecting
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true

#if FEATURE_3
        let listener = try NWListener(using: parameters, on: 34962)
#else
        let listener = try NWListener(using: parameters, on: 34963)
#endif
        listener.service = .init(type: "_vcammocap._udp", domain: "local")
        self.listener = listener

        return try await withCheckedThrowingContinuation { [weak self] continuation in
            listener.stateUpdateHandler = { newState in
                switch newState {
                case .failed(let error):
                    Logger.log("Listener failed: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    Task { @MainActor in
                        await self?.handleDisconnection()
                    }
                case .cancelled:
                    Logger.log("Listener cancelled")
                    continuation.resume(throwing: Error.cancelled)
                    Task { @MainActor in
                        await self?.handleDisconnection()
                    }
                default: ()
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.connection = connection
                connection.stateUpdateHandler = { [weak self] state in
                     Task { @MainActor [weak self] in
                        switch state {
                        case .setup, .preparing: ()
                        case .waiting(let error):
                            Logger.log("Connection waiting: \(error.localizedDescription)")
                        case .ready:
                            Logger.log("Connection ready")
                            self?.connectionStatus = .connected
                            self?.resetTimeoutTimer()
                            connection.receiveData(with: tracking.onVCamMotionReceived, onDataReceived: { [weak self] in
                                Task { @MainActor in
                                    self?.resetTimeoutTimer()
                                }
                            })
                        case .cancelled:
                            Logger.log("Connection cancelled")
                            await self?.handleDisconnection()
                        case .failed(let error):
                            Logger.log("Connection failed: \(error.localizedDescription)")
                            await self?.handleDisconnection()
                        @unknown default: ()
                        }
                    }
                }

                connection.start(queue: Self.queue)
            }
            listener.start(queue: Self.queue)
        }
    }

    @MainActor
    public func stop() {
        shouldAutoReconnect = false
        stopInternal()
    }

    @MainActor
    private func stopInternal() {
        timeoutTask?.cancel()
        timeoutTask = nil

        if let listener = listener {
            listener.stateUpdateHandler = nil
            listener.newConnectionHandler = nil
            listener.cancel()
            self.listener = nil
        }

        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        connectionStatus = .disconnected
        tracking?.stop()
    }

    @MainActor
    private func resetTimeoutTimer() {
        timeoutTask?.cancel()
        timeoutTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: Self.dataTimeoutSeconds * NSEC_PER_SEC)
                Logger.log("Data timeout - resetting listener")
                await self?.handleTimeout()
            } catch {}
        }
    }

    @MainActor
    private func handleTimeout() async {
        guard connectionStatus == .connected, shouldAutoReconnect, let tracking = tracking else { return }
        stopInternal()
        do {
            try await start(with: tracking)
        } catch {
            Logger.log("Restart failed: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func handleDisconnection() async {
        guard shouldAutoReconnect, let tracking = tracking else {
            stopInternal()
            return
        }
        stopInternal()
        do {
            try await start(with: tracking)
        } catch {
            Logger.log("Restart failed: \(error.localizedDescription)")
        }
    }
}

private extension NWConnection {
    func receiveData(
        with onVCamMotionReceived: @escaping @Sendable (VCamMotion, Tracking) -> Void,
        onDataReceived: @escaping @Sendable () -> Void
    ) {
        receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] content, contentContext, isComplete, error in
            defer {
                self?.receiveData(with: onVCamMotionReceived, onDataReceived: onDataReceived)
            }

            guard error == nil,
                  let content,
                  content.count == MemoryLayout<VCamMotion>.size else {
                return
            }
            onDataReceived()
            let mocapData = VCamMotion(rawData: content)
            onVCamMotionReceived(mocapData, .shared)
        }
    }
}
