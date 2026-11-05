import Foundation
import Network
import Observation
import Synchronization
import VCamTrackingCore

/// Listens as a VMC Protocol marionette: a performer (a motion capture app) sends the bones and expressions of
/// its avatar over OSC, and the frames go to `frameHandler` at the renderer's frame times
@Observable
@MainActor
public final class VMCProtocolReceiver {
    /// Receives each frame, resampled to the renderer's frame times. nil once the performer stops sending
    public static var frameHandler: ((VMCPerformerFrame?) -> Void)?

    nonisolated private static let queue = DispatchQueue(label: "com.github.tattn.vcam.vmcprotocolreceiver")

    public private(set) var connectionStatus = ConnectionStatus.disconnected
    /// Off leaves the face to the face tracking, even when the performer sends expressions
    public var receivesExpressions = true {
        didSet { relay.expressions = nil }
    }

    @ObservationIgnored private let session = UDPDatagramSession()
    @ObservationIgnored nonisolated private let smoothingStorage: TrackingSmoothingStorage
    @ObservationIgnored nonisolated private let resampler: TrackingResampler
    /// Written on the receive queue, and taken or reset from the main actor
    @ObservationIgnored nonisolated private let inbox = Mutex(Inbox())
    @ObservationIgnored private let relay: FrameRelay
    @ObservationIgnored private var port: NWEndpoint.Port?
    @ObservationIgnored private let restartRetry = ListenerRestartRetry()
    @ObservationIgnored private let timeoutWatchdog = DataTimeoutWatchdog(timeout: .seconds(1))

    public init(smoothing: TrackingSmoothing) {
        let smoothingStorage = TrackingSmoothingStorage(smoothing)
        self.smoothingStorage = smoothingStorage
        let relay = FrameRelay()
        self.relay = relay
        resampler = TrackingResampler(label: "vmc", settingsProvider: smoothingStorage.settingsProvider) { @MainActor values in
            relay.deliver(VMCPerformerState.frame(fromResamplerValues: values))
        }
    }

    public var isRunning: Bool { session.isRunning }

    /// Throws only when the listener cannot be created. Failures after startup restart the listener
    public func start(port: Int) throws {
        guard !session.isRunning else { return }
        guard let endpointPort = NWEndpoint.Port(rawValue: UInt16(clamping: port)) else {
            throw NWError.posix(.EINVAL)
        }
        try session.start(
            on: endpointPort,
            queue: Self.queue,
            onEnded: { [weak self] in
                self?.restartIfNeeded()
            },
            onReady: {},
            receive: { [weak self] data, receivedAt in
                self.map { Self.receive(data, receivedAt: receivedAt, inbox: $0.inbox) } ?? false
            },
            onData: { [weak self] updated in
                if updated {
                    self?.takeReceived()
                }
            }
        )
        self.port = endpointPort
        connectionStatus = .connecting
    }

    public func stop() {
        port = nil
        restartRetry.cancel()
        stopInternal()
    }

    nonisolated func updateSmoothing(_ smoothing: TrackingSmoothing) {
        smoothingStorage.update(smoothing)
        if !smoothing.isEnabled {
            Task { @MainActor in
                resampler.stop()
            }
        }
    }

    /// A performer may split a frame over several bundles, each its own datagram. They pile up here, and the main
    /// actor takes only the latest values, so the frame reaches the resampler once instead of once per bundle
    private struct Inbox: Sendable {
        var performer = VMCPerformerState()
        /// What changed since the main actor last took it
        var pending = VMCPerformerState.Update()
        /// When the latest values of the body arrived
        var receivedAt: TimeInterval = 0

        mutating func takePending() -> Received? {
            guard !pending.isEmpty else { return nil }
            defer { pending = VMCPerformerState.Update() }
            return Received(values: pending.movesBody ? performer.resamplerValues : nil,
                            expressions: pending.appliesExpressions ? performer.expressions : nil,
                            receivedAt: receivedAt)
        }
    }

    private struct Received: Sendable {
        var values: [Float]?
        /// Set when `/VMC/Ext/Blend/Apply` arrived
        var expressions: [String: Float]?
        var receivedAt: TimeInterval
    }

    /// Whether the datagram changed anything for the main actor to take
    nonisolated private static func receive(_ data: Data, receivedAt: TimeInterval,
                                            inbox: borrowing Mutex<Inbox>) -> Bool {
        inbox.withLock { inbox in
            let update = inbox.performer.receive(data)
            if update.movesBody {
                inbox.receivedAt = receivedAt
            }
            inbox.pending.merge(update)
            return !update.isEmpty
        }
    }

    /// Each changing datagram hops here, so a hop finds nothing once an earlier one has taken its values
    private func takeReceived() {
        guard let received = inbox.withLock({ $0.takePending() }) else { return }
        timeoutWatchdog.markDataReceived()
        if connectionStatus != .connected {
            connectionStatus = .connected
            relay.isDelivering = true
            startTimeoutWatchdog()
        }
        if let expressions = received.expressions, receivesExpressions {
            relay.expressions = expressions
            if received.values == nil {
                // A performer sending only the face still needs it delivered
                relay.deliverExpressions()
            }
        }
        if let values = received.values {
            resampler.send(values, smoothed: smoothingStorage.isEnabled, receivedAt: received.receivedAt)
        }
    }

    private func startTimeoutWatchdog() {
        timeoutWatchdog.start(
            isActive: { [weak self] in
                self?.connectionStatus == .connected
            },
            onTimeout: { [weak self] in
                self?.performerLost()
            }
        )
    }

    /// The listener stays: the performer may come back on the same port
    private func performerLost() {
        timeoutWatchdog.stop()
        connectionStatus = session.isRunning ? .connecting : .disconnected
        resampler.stop()
        inbox.withLock { $0 = Inbox() }
        relay.reset()
        Self.frameHandler?(nil)
    }

    private func stopInternal() {
        session.stop()
        performerLost()
    }

    private func restartIfNeeded() {
        restartRetry.cancel()
        stopInternal()
        guard let port else { return }
        restartRetry.start {
            try start(port: Int(port.rawValue))
        } orRetry: { [weak self] in
            self?.restartIfNeeded()
        }
    }
}

/// Joins the resampled bones with the latest expressions on their way to `frameHandler`
@MainActor
private final class FrameRelay {
    /// Off once the performer is gone, so a resampler sample still in flight does not bring it back
    var isDelivering = false
    /// The expressions of the last `/VMC/Ext/Blend/Apply`, going out with every frame
    var expressions: [String: Float]?
    /// The last bones, for expressions arriving between them
    private var lastFrame: VMCPerformerFrame?

    func deliver(_ frame: VMCPerformerFrame) {
        guard isDelivering else { return }
        var frame = frame
        frame.expressions = expressions
        lastFrame = frame
        VMCProtocolReceiver.frameHandler?(frame)
    }

    func deliverExpressions() {
        deliver(lastFrame ?? VMCPerformerFrame(bones: [:]))
    }

    func reset() {
        isDelivering = false
        expressions = nil
        lastFrame = nil
    }
}
