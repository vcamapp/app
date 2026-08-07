import Network
import Combine
import VCamBridge
import Accelerate
import VCamLogger
import Synchronization

@Observable
@MainActor
public final class FacialMocapReceiver {
    @ObservationIgnored private let session = UDPDatagramSession()
    @ObservationIgnored private var facialMocapLastValues: [Float] = Array(repeating: 0, count: 12)
    @ObservationIgnored private var blendShapeResampler: TrackingResampler
    @ObservationIgnored private var perfectSyncResampler: TrackingResampler
    @ObservationIgnored private let smoothingStorage: TrackingSmoothingStorage
    nonisolated private static let queue = DispatchQueue(label: "com.github.tattn.vcam.facialmocapreceiver")
    /// Bumped on every stop so the handshake retry loop, which runs off the
    /// MainActor, abandons itself once its session is gone.
    nonisolated private let handshakeGeneration = Mutex(0)

    public private(set) var connectionStatus = ConnectionStatus.disconnected

    @ObservationIgnored private var shouldAutoReconnect = true
    @ObservationIgnored private var lastConnectedIP: String?
    @ObservationIgnored private var timeoutWatchdogTask: Task<Void, Never>?
    @ObservationIgnored private var lastDataReceivedAt = ContinuousClock.now

    private static let dataTimeout: Duration = .seconds(2)

#if FEATURE_3
    nonisolated private static let port = NWEndpoint.Port(integerLiteral: 49983)
#else
    nonisolated private static let port = NWEndpoint.Port(integerLiteral: 49984)
#endif

    public init(smoothing: TrackingSmoothing) {
        let smoothingStorage = TrackingSmoothingStorage(smoothing)
        self.smoothingStorage = smoothingStorage
        let settingsProvider = smoothingStorage.settingsProvider

        blendShapeResampler = TrackingResampler(label: "facial-mocap-blendshape", settingsProvider: settingsProvider) { @MainActor values in
            UniBridge.shared.receiveVCamBlendShape(values)
        }

        perfectSyncResampler = TrackingResampler(label: "facial-mocap-perfectsync", settingsProvider: settingsProvider) { @MainActor values in
            UniBridge.shared.receivePerfectSync(values)
        }
    }

    /// Throws only when the listener cannot be created. Failures after
    /// startup are handled by the state handlers, which restart the listener.
    public func connect(ip: String) async throws {
        stopInternal()
        shouldAutoReconnect = true
        lastConnectedIP = ip

        try startServer()
        requestConnection(ip: ip, generation: handshakeGeneration.withLock { $0 })
    }

    public func stop() async {
        shouldAutoReconnect = false
        stopInternal()
    }

    private func stopInternal() {
        handshakeGeneration.withLock { $0 += 1 }
        timeoutWatchdogTask?.cancel()
        timeoutWatchdogTask = nil

        session.stop()
        connectionStatus = .disconnected

        stopResamplers()
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
                // Not `== .connected`: a connection stuck in .waiting never
                // reaches .ready and has to be restarted too.
                guard self.connectionStatus != .disconnected,
                      ContinuousClock.now - self.lastDataReceivedAt > Self.dataTimeout else { continue }
                Logger.log("Data timeout - resetting listener")
                await self.restartIfNeeded()
                return
            }
        }
    }

    private func restartIfNeeded() async {
        guard shouldAutoReconnect, let ip = lastConnectedIP else {
            stopInternal()
            return
        }
        do {
            try await connect(ip: ip)
        } catch {
            Logger.log("Restart failed: \(error.localizedDescription)")
        }
    }

    nonisolated func updateSmoothing(_ smoothing: TrackingSmoothing) {
        smoothingStorage.update(smoothing)
        if !smoothing.isEnabled {
            Task { @MainActor in
                stopResamplers()
            }
        }
    }

    private func oniFacialMocapReceived(_ data: FacialMocapData) {
        guard Tracking.shared.faceTrackingMethod == .iFacialMocap else { return }

        let smoothingEnabled = smoothingStorage.isEnabled
        if UniBridge.shared.hasPerfectSyncBlendShape {
            let perfectSync = data.perfectSync(useEyeTracking: Tracking.shared.useEyeTracking)
            perfectSyncResampler.send(perfectSync, smoothed: smoothingEnabled)
        } else {
            let blendShape = data.vcamHeadTransform(useEyeTracking: Tracking.shared.useEyeTracking)
            facialMocapLastValues = vDSP.linearInterpolate(
                facialMocapLastValues,
                blendShape,
                using: 0.5
            )

            blendShapeResampler.send(facialMocapLastValues, smoothed: smoothingEnabled)
        }
    }

    func stopResamplers() {
        blendShapeResampler.stop()
        perfectSyncResampler.stop()
    }
}

extension FacialMocapReceiver {
    private func startServer() throws {
        try session.start(
            on: Self.port,
            queue: Self.queue,
            onEnded: { [weak self] in
                Task {
                    await self?.restartIfNeeded()
                }
            },
            onConnectionStarted: { [weak self] in
                guard let self else { return }
                self.lastDataReceivedAt = .now
                self.startTimeoutWatchdog()
            },
            onReady: { [weak self] in
                guard let self else { return }
                self.connectionStatus = .connected
                self.lastDataReceivedAt = .now
                self.startTimeoutWatchdog()
            },
            onData: { [weak self] data in
                guard let self,
                      let rawData = String(data: data, encoding: .utf8),
                      let mocapData = FacialMocapData(rawData: rawData) else { return }
                self.lastDataReceivedAt = .now
                self.oniFacialMocapReceived(mocapData)
            }
        )
        connectionStatus = .connecting
    }
}

extension FacialMocapReceiver {
    /// Asks the sender to start streaming. Data arrives on the listener above,
    /// so this connection is only needed until the token lands and a failure
    /// here retries the handshake instead of restarting the listener.
    private nonisolated func requestConnection(ip: String, generation: Int) {
        let connection = NWConnection(host: NWEndpoint.Host(ip), port: Self.port, using: .udp)

        @Sendable func finish() {
            connection.stateUpdateHandler = nil
            connection.cancel()
        }

        @Sendable func retry() {
            finish()
            Self.queue.asyncAfter(deadline: .now() + 2) { [self] in
                guard handshakeGeneration.withLock({ $0 }) == generation else { return }
                requestConnection(ip: ip, generation: generation)
            }
        }

        connection.stateUpdateHandler = { [self] state in
            guard handshakeGeneration.withLock({ $0 }) == generation else {
                finish()
                return
            }
            switch state {
            case .setup, .preparing, .cancelled: ()
            case .waiting(let error):
                Logger.log("Start token connection waiting: \(error.localizedDescription)")
                retry()
            case .ready:
                let token = "iFacialMocap_sahuasouryya9218sauhuiayeta91555dy3719|sendDataVersion=v2".data(using: .utf8)
                connection.send(content: token, completion: .contentProcessed { error in
                    if let error {
                        Logger.log("Failed to send the start token: \(error.localizedDescription)")
                        retry()
                    } else {
                        finish()
                    }
                })
            case .failed(let error):
                Logger.log("Start token connection failed: \(error.localizedDescription)")
                retry()
            @unknown default: ()
            }
        }
        connection.start(queue: Self.queue)
    }
}
