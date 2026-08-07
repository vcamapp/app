import Foundation
import Network
import Observation
import VCamMotionV1
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
    @ObservationIgnored private let session = UDPDatagramSession()
    @ObservationIgnored private weak var tracking: VCamMotionTracking?
    @ObservationIgnored private var settings: (@MainActor () -> VCamMotionTrackingSettings)?
    @ObservationIgnored private var motionV1Receiver: MotionV1Receiver?

    public private(set) var connectionStatus = ConnectionStatus.disconnected
    public private(set) var motionProtocolVersion: VCamMotionProtocolVersion?

    @ObservationIgnored private var shouldAutoReconnect = true
    @ObservationIgnored private var restartRetryTask: Task<Void, Never>?
    @ObservationIgnored private let timeoutWatchdog = DataTimeoutWatchdog(timeout: .seconds(2))

    public init() {}

    /// Throws only when the listener cannot be created. Failures after
    /// startup are handled by the state handlers, which restart the listener.
    func start(with tracking: VCamMotionTracking, settings: @escaping @MainActor () -> VCamMotionTrackingSettings) throws {
        guard !session.isRunning else { return }

#if FEATURE_3
        let port = NWEndpoint.Port(integerLiteral: 34962)
#else
        let port = NWEndpoint.Port(integerLiteral: 34963)
#endif

        let service: NWListener.Service
        if #available(macOS 26.0, *) {
            service = .init(
                type: "_vcammocap._udp",
                domain: "local",
                txtRecord: .init([MotionPacketV1Constants.motionProtocolsTXTRecordKey: "0,1"])
            )
        } else {
            service = .init(type: "_vcammocap._udp", domain: "local")
        }

        let motionV1Receiver = MotionV1Receiver(
            onFace: { [weak tracking] data in tracking?.applyFace(data, settings: settings()) },
            onHands: { [weak tracking] data in tracking?.applyHandsV1(data, settings: settings()) }
        )
        try session.start(
            on: port,
            service: service,
            queue: Self.queue,
            onEnded: { [weak self] in
                self?.restartIfNeeded()
            },
            onConnectionStarted: { [weak self] in
                self?.motionV1Receiver?.resetForNewConnection()
            },
            onReady: { [weak self] in
                guard let self else { return }
                self.connectionStatus = .connected
                self.startTimeoutWatchdog()
            },
            onData: { [weak self] data in
                self?.handleData(data)
            }
        )
        self.tracking = tracking
        self.settings = settings
        self.motionV1Receiver = motionV1Receiver
        shouldAutoReconnect = true
        connectionStatus = .connecting
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

        guard data.count == MemoryLayout<VCamMotion>.size, let settings else { return }
        markDataReceived(protocolVersion: .v0)
        tracking?.applyLegacyMotion(VCamMotion(rawData: data), settings: settings())
    }

    /// Only handled packets keep the connection alive. If nothing but
    /// rejected packets arrives (e.g. a stale face session ID after the
    /// sender restarted), the watchdog resets the listener, which also
    /// resets the sequence/session state via `resetForNewConnection()`.
    private func markDataReceived(protocolVersion version: VCamMotionProtocolVersion) {
        timeoutWatchdog.markDataReceived()
        if motionProtocolVersion != version {
            motionProtocolVersion = version
        }
    }

    public func stop() {
        shouldAutoReconnect = false
        cancelRestartRetry()
        stopInternal()
    }

    private func stopInternal() {
        timeoutWatchdog.stop()

        session.stop()
        motionV1Receiver = nil
        motionProtocolVersion = nil
        connectionStatus = .disconnected
        tracking?.stop()
    }

    private func startTimeoutWatchdog() {
        timeoutWatchdog.start(
            isActive: { [weak self] in
                self?.connectionStatus == .connected
            },
            onTimeout: { [weak self] in
                self?.restartIfNeeded()
            }
        )
    }

    private func restartIfNeeded() {
        cancelRestartRetry()
        guard shouldAutoReconnect, let tracking, let settings else {
            stopInternal()
            return
        }
        stopInternal()
        do {
            try start(with: tracking, settings: settings)
        } catch {
            // A failed restart leaves no listener or watchdog to trigger
            // another reconnect, so retry after a delay.
            Logger.log("Restart failed: \(error.localizedDescription)")
            restartRetryTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.restartIfNeeded()
            }
        }
    }

    private func cancelRestartRetry() {
        restartRetryTask?.cancel()
        restartRetryTask = nil
    }
}
