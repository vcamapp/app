import Foundation
import Network
import Observation
import VCamLogger

public enum VCamMotionProtocolVersion: Equatable, Sendable {
    case v0
    case v1

    public var displayName: String {
        switch self {
        case .v0: "VCamMotion v0"
        case .v1: "VCamMotion v1"
        }
    }
}

@Observable
@MainActor
public final class VCamMotionReceiver {
    private static let queue = DispatchQueue(label: "com.github.tattn.vcam.vcammotionreceiver")
    @ObservationIgnored private var listener: NWListener?
    @ObservationIgnored private var connection: NWConnection?
    @ObservationIgnored private weak var tracking: VCamMotionTracking?
    @ObservationIgnored private var motionV1Receiver: MotionV1Receiver?

    public private(set) var connectionStatus = ConnectionStatus.disconnected
    public private(set) var motionProtocolVersion: VCamMotionProtocolVersion?

    @ObservationIgnored private var shouldAutoReconnect = true
    @ObservationIgnored private var timeoutWatchdogTask: Task<Void, Never>?
    @ObservationIgnored private var lastDataReceivedAt = ContinuousClock.now

    private static let dataTimeout: Duration = .seconds(2)

    public init() {}

    /// Throws only when the listener cannot be created. Failures after
    /// startup are handled by the state handlers, which restart the listener.
    func start(with tracking: VCamMotionTracking) throws {
        guard listener == nil else { return }

        self.tracking = tracking
        motionV1Receiver = MotionV1Receiver(
            onFace: { [weak tracking] data in tracking?.applyFace(data, tracking: Tracking.shared) },
            onHands: { [weak tracking] data in tracking?.applyHandsV1(data, tracking: Tracking.shared) }
        )
        shouldAutoReconnect = true
        connectionStatus = .connecting
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true

#if FEATURE_3
        let listener = try NWListener(using: parameters, on: 34962)
#else
        let listener = try NWListener(using: parameters, on: 34963)
#endif
        if #available(macOS 26.0, *) {
            listener.service = .init(type: "_vcammocap._udp", domain: "local",
                                      txtRecord: .init([MotionPacketV1Constants.motionProtocolsTXTRecordKey: "0,1"]))
        } else {
            listener.service = .init(type: "_vcammocap._udp", domain: "local")
        }
        self.listener = listener

        listener.stateUpdateHandler = { [weak self, weak listener] newState in
            switch newState {
            case .failed(let error):
                Logger.log("Listener failed: \(error.localizedDescription)")
            case .cancelled:
                Logger.log("Listener cancelled")
            default:
                return
            }
            Task { @MainActor in
                guard let self, let listener, self.listener === listener else { return }
                self.restartIfNeeded()
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in
                guard let self else { return }
                // Cancel the stale connection so its late .failed/.cancelled
                // cannot restart the listener under the new one.
                self.connection?.stateUpdateHandler = nil
                self.connection?.cancel()
                self.connection = connection
                self.motionV1Receiver?.resetForNewConnection()
                connection.stateUpdateHandler = { [weak self, weak connection] state in
                     Task { @MainActor in
                        guard let self, let connection, self.connection === connection else { return }
                        switch state {
                        case .setup, .preparing: ()
                        case .waiting(let error):
                            Logger.log("Connection waiting: \(error.localizedDescription)")
                        case .ready:
                            Logger.log("Connection ready")
                            self.connectionStatus = .connected
                            self.lastDataReceivedAt = .now
                            self.startTimeoutWatchdog()
                            connection.receiveData { [weak self, weak connection] data in
                                Task { @MainActor in
                                    guard let self, let connection, self.connection === connection else { return }
                                    self.handleData(data)
                                }
                            }
                        case .cancelled:
                            Logger.log("Connection cancelled")
                            self.restartIfNeeded()
                        case .failed(let error):
                            Logger.log("Connection failed: \(error.localizedDescription)")
                            self.restartIfNeeded()
                        @unknown default: ()
                        }
                    }
                }

                connection.start(queue: Self.queue)
            }
        }
        listener.start(queue: Self.queue)
    }

    private func handleData(_ data: Data) {
        // v1 packets have an explicit header; legacy packets do not.
        if let receiver = motionV1Receiver {
            switch receiver.receive(data) {
            case .handledV1:
                markDataReceived(protocolVersion: .v1)
                return
            case .rejectedV1:
                return
            case .notV1:
                break
            }
        }

        guard data.count == MemoryLayout<VCamMotion>.size else { return }
        markDataReceived(protocolVersion: .v0)
        tracking?.applyLegacyMotion(VCamMotion(rawData: data), tracking: Tracking.shared)
    }

    /// Only handled packets keep the connection alive. If nothing but
    /// rejected packets arrives (e.g. a stale face session ID after the
    /// sender restarted), the watchdog resets the listener, which also
    /// resets the sequence/session state via `resetForNewConnection()`.
    private func markDataReceived(protocolVersion version: VCamMotionProtocolVersion) {
        lastDataReceivedAt = .now
        if motionProtocolVersion != version {
            motionProtocolVersion = version
        }
    }

    public func stop() {
        shouldAutoReconnect = false
        stopInternal()
    }

    private func stopInternal() {
        timeoutWatchdogTask?.cancel()
        timeoutWatchdogTask = nil

        if let listener = listener {
            listener.stateUpdateHandler = nil
            listener.newConnectionHandler = nil
            listener.cancel()
            self.listener = nil
        }

        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        motionV1Receiver = nil
        motionProtocolVersion = nil
        connectionStatus = .disconnected
        tracking?.stop()
    }

    /// A single long-lived task checks the last receive time periodically, so
    /// each incoming packet only has to update a timestamp instead of
    /// cancelling and recreating a timer task at packet rate.
    private func startTimeoutWatchdog() {
        guard timeoutWatchdogTask == nil else { return }
        timeoutWatchdogTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                guard self.connectionStatus == .connected,
                      ContinuousClock.now - self.lastDataReceivedAt > Self.dataTimeout else { continue }
                Logger.log("Data timeout - resetting listener")
                self.restartIfNeeded()
                return
            }
        }
    }

    private func restartIfNeeded() {
        guard shouldAutoReconnect, let tracking else {
            stopInternal()
            return
        }
        stopInternal()
        do {
            try start(with: tracking)
        } catch {
            Logger.log("Restart failed: \(error.localizedDescription)")
        }
    }
}

private extension NWConnection {
    func receiveData(with dataHandler: @escaping @Sendable (Data) -> Void) {
        receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] content, _, _, error in
            // A failed or cancelled connection must not re-arm the receive;
            // it would spin against a dead connection.
            guard let self, error == nil else { return }
            if let content, !content.isEmpty {
                dataHandler(content)
            }
            self.receiveData(with: dataHandler)
        }
    }
}
