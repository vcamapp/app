import Foundation
import Network
import Observation
import Synchronization
import VCamLogger
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
    /// Written on the receive queue, and reset from the main actor when the performer is gone
    @ObservationIgnored nonisolated private let performer = Mutex(VMCPerformerState())
    @ObservationIgnored private let relay: FrameRelay
    @ObservationIgnored private var port: NWEndpoint.Port?
    @ObservationIgnored private var restartRetryTask: Task<Void, Never>?
    @ObservationIgnored private let timeoutWatchdog = DataTimeoutWatchdog(timeout: .seconds(1))

    public init(smoothing: TrackingSmoothing) {
        let smoothingStorage = TrackingSmoothingStorage(smoothing)
        self.smoothingStorage = smoothingStorage
        let relay = FrameRelay()
        self.relay = relay
        resampler = TrackingResampler(label: "vmc", settingsProvider: smoothingStorage.settingsProvider) { @MainActor values in
            relay.deliver(VMCPerformerState.frame(fromResamplerValues: values, expressions: nil))
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
                self.flatMap { Self.receive(data, receivedAt: receivedAt, performer: $0.performer) }
            },
            onData: { [weak self] received in
                self?.handle(received)
            }
        )
        self.port = endpointPort
        connectionStatus = .connecting
    }

    public func stop() {
        port = nil
        cancelRestartRetry()
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

    private struct Received: Sendable {
        var values: [Float]?
        /// Set when `/VMC/Ext/Blend/Apply` arrived
        var expressions: [String: Float]?
        var receivedAt: TimeInterval
    }

    nonisolated private static func receive(_ data: Data, receivedAt: TimeInterval,
                                            performer: borrowing Mutex<VMCPerformerState>) -> Received? {
        let messages = OSCPacketReader.messages(in: data)
        guard !messages.isEmpty else { return nil }
        return performer.withLock { performer in
            let update = performer.receive(messages)
            guard update.movesBody || update.appliesExpressions else { return nil }
            return Received(values: update.movesBody ? performer.resamplerValues : nil,
                            expressions: update.appliesExpressions ? performer.expressions : nil,
                            receivedAt: receivedAt)
        }
    }

    private func handle(_ received: Received?) {
        guard let received else { return }
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
        performer.withLock { $0.reset() }
        relay.reset()
        Self.frameHandler?(nil)
    }

    private func stopInternal() {
        session.stop()
        performerLost()
    }

    private func restartIfNeeded() {
        cancelRestartRetry()
        guard let port else {
            stopInternal()
            return
        }
        stopInternal()
        do {
            try start(port: Int(port.rawValue))
        } catch {
            // A failed restart leaves no listener to trigger another one, so retry after a delay
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
