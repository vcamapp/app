import Network
import Combine
import VCamBridge
import Accelerate
import VCamLogger
import Synchronization
import VCamTrackingCore

@Observable
@MainActor
public final class FacialMocapReceiver {
    @ObservationIgnored private let session = UDPDatagramSession()
    @ObservationIgnored nonisolated private let faceRoute: FaceResamplerRoute
    @ObservationIgnored private let smoothingStorage: TrackingSmoothingStorage
    nonisolated private static let queue = DispatchQueue(label: "com.github.tattn.vcam.facialmocapreceiver")
    /// Bumped on every stop so the handshake retry loop, which runs off the
    /// MainActor, abandons itself once its session is gone.
    nonisolated private let handshakeGeneration = Mutex(0)

    public private(set) var connectionStatus = ConnectionStatus.disconnected

    @ObservationIgnored private var shouldAutoReconnect = true
    @ObservationIgnored private var lastConnectedIP: String?
    @ObservationIgnored private let timeoutWatchdog = DataTimeoutWatchdog(timeout: .seconds(2))

#if FEATURE_3
    nonisolated private static let port = NWEndpoint.Port(integerLiteral: 49983)
#else
    nonisolated private static let port = NWEndpoint.Port(integerLiteral: 49984)
#endif

    public init(smoothing: TrackingSmoothing) {
        let smoothingStorage = TrackingSmoothingStorage(smoothing)
        self.smoothingStorage = smoothingStorage
        faceRoute = FaceResamplerRoute(labelPrefix: "facial-mocap", smoothingStorage: smoothingStorage)
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
        timeoutWatchdog.stop()

        session.stop()
        connectionStatus = .disconnected

        stopResamplers()
    }

    private func startTimeoutWatchdog() {
        timeoutWatchdog.start(
            isActive: { [weak self] in
                guard let self else { return false }
                // Not `== .connected`: a connection stuck in .waiting never
                // reaches .ready and has to be restarted too.
                return self.connectionStatus != .disconnected
            },
            onTimeout: { [weak self] in
                await self?.restartIfNeeded()
            }
        )
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

    /// A datagram parsed on the receive queue, and whether the face already went to the resamplers there
    private struct Received: Sendable {
        var data: FacialMocapData
        var receivedAt: TimeInterval
        var facePushed: Bool
    }

    nonisolated private static func receive(_ data: Data, receivedAt: TimeInterval, route: FaceResamplerRoute) -> Received? {
        guard let rawData = String(data: data, encoding: .utf8),
              let mocapData = FacialMocapData(rawData: rawData) else { return nil }
        let facePushed = route.push(at: receivedAt) { conversion, previousBlendShape in
            faceValues(mocapData, conversion: conversion, previousBlendShape: &previousBlendShape)
        }
        return Received(data: mocapData, receivedAt: receivedAt, facePushed: facePushed)
    }

    private func handle(_ received: Received?) {
        guard let received else { return }
        timeoutWatchdog.markDataReceived()
        faceRoute.send(faceConversion(), pushed: received.facePushed, receivedAt: received.receivedAt) { conversion, previousBlendShape in
            Self.faceValues(received.data, conversion: conversion, previousBlendShape: &previousBlendShape)
        }
    }

    private func faceConversion() -> FaceResamplerRoute.Conversion? {
        let tracking = Tracking.shared
        guard tracking.faceTrackingMethod == .iFacialMocap, let mode = tracking.activeFaceMappingMode else { return nil }
        return .init(mode: mode, useEyeTracking: tracking.useEyeTracking, useVowelEstimation: false,
                     mirrorsTracking: tracking.mirrorsTracking)
    }

    /// The blend shape array is halved toward the previous packet's before resampling
    nonisolated private static func faceValues(_ data: FacialMocapData, conversion: FaceResamplerRoute.Conversion,
                                               previousBlendShape: inout [Float]?) -> [Float] {
        switch conversion.mode {
        case .perfectSync:
            return data.perfectSync(useEyeTracking: conversion.useEyeTracking, mirrored: conversion.mirrorsTracking)
        case .blendShape:
            let values = data.vcamHeadTransform(useEyeTracking: conversion.useEyeTracking, mirrored: conversion.mirrorsTracking)
            let filtered = previousBlendShape.map { vDSP.linearInterpolate($0, values, using: 0.5) } ?? values
            previousBlendShape = filtered
            return filtered
        }
    }

    func stopResamplers() {
        faceRoute.stop()
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
                self.startTimeoutWatchdog()
            },
            onReady: { [weak self] in
                guard let self else { return }
                self.connectionStatus = .connected
                self.startTimeoutWatchdog()
            },
            receive: { [faceRoute] data, receivedAt in
                Self.receive(data, receivedAt: receivedAt, route: faceRoute)
            },
            onData: { [weak self] received in
                self?.handle(received)
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
