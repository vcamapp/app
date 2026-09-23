import Foundation
import Network
import Observation
import VCamMotionV1
import VCamLogger
import VCamTrackingCore

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

        let parser = MotionV1Receiver()
        try session.start(
            on: port,
            service: service,
            queue: Self.queue,
            onEnded: { [weak self] in
                self?.restartIfNeeded()
            },
            onConnectionStarted: {
                parser.resetForNewConnection()
            },
            onReady: { [weak self] in
                guard let self else { return }
                self.connectionStatus = .connected
                TrackingTraceRecorder.shared.recordEvent("vcamMotion.connected")
                self.startTimeoutWatchdog()
            },
            receive: { [weak tracking] data, receivedAt in
                Self.receive(data, receivedAt: receivedAt, parser: parser, tracking: tracking)
            },
            onData: { [weak self] received in
                self?.handle(received)
            }
        )
        self.tracking = tracking
        self.settings = settings
        shouldAutoReconnect = true
        connectionStatus = .connecting
    }

    /// A datagram after the receive queue has decoded it and, when it could, pushed the face
    private struct Received: Sendable {
        enum Content: Sendable {
            case face(VCamMotion)
            case hands(Data)
            case legacy(VCamMotion)
        }

        var content: Content
        var receivedAt: TimeInterval
        var facePushed: Bool
    }

    /// On the receive queue. The face goes to the resamplers from here; everything else, and
    /// the bookkeeping, waits for the main actor
    nonisolated private static func receive(_ data: Data, receivedAt: TimeInterval, parser: MotionV1Receiver,
                                            tracking: VCamMotionTracking?) -> Received? {
        // v1 packets have an explicit header; legacy packets do not.
        let content: Received.Content
        switch parser.receive(data) {
        case .face(let motion):
            content = .face(motion)
        case .hands(let packet):
            content = .hands(packet)
        case .rejected:
            return nil
        case .notV1:
            guard data.count == MemoryLayout<VCamMotion>.size else { return nil }
            content = .legacy(VCamMotion(rawData: data))
        }
        let facePushed = switch content {
        case .face(let motion), .legacy(let motion): tracking?.pushFaceFromReceiveQueue(motion, receivedAt: receivedAt) ?? false
        case .hands: false
        }
        return Received(content: content, receivedAt: receivedAt, facePushed: facePushed)
    }

    private func handle(_ received: Received?) {
        guard let received, let settingsProvider = settings, let tracking else { return }
        let settings = settingsProvider()
        switch received.content {
        case .face(let motion):
            markDataReceived(protocolVersion: .v1)
            tracking.applyFace(motion, pushed: received.facePushed, settings: settings, receivedAt: received.receivedAt)
        case .hands(let packet):
            markDataReceived(protocolVersion: .v1)
            tracking.applyHandsV1(packet, settings: settings)
        case .legacy(let motion):
            markDataReceived(protocolVersion: .v0)
            tracking.applyFace(motion, pushed: received.facePushed, settings: settings, receivedAt: received.receivedAt)
            tracking.applyLegacyHands(motion, settings: settings, receivedAt: received.receivedAt)
        }
    }

    /// Only handled packets keep the connection alive. If nothing but
    /// rejected packets arrives (e.g. a stale face session ID after the
    /// sender restarted), the watchdog resets the listener, which also
    /// resets the sequence/session state via `resetForNewConnection()`.
    private func markDataReceived(protocolVersion version: VCamMotionProtocolVersion) {
        timeoutWatchdog.markDataReceived()
        if motionProtocolVersion != version {
            motionProtocolVersion = version
            TrackingTraceRecorder.shared.recordEvent("vcamMotion.protocol", ["version": version.displayName])
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
                TrackingTraceRecorder.shared.recordEvent("vcamMotion.timeout")
                self?.restartIfNeeded()
            }
        )
    }

    private func restartIfNeeded() {
        TrackingTraceRecorder.shared.recordEvent("vcamMotion.restart")
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
