//
//  FacialMocapReceiver.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/01/02.
//

import Network
import Combine
import VCamBridge
import Accelerate
import VCamLogger

@Observable
public final class FacialMocapReceiver: @unchecked Sendable { // TODO: Fix Sendable conformance
    @ObservationIgnored private var listener: NWListener?
    @ObservationIgnored private var connection: NWConnection?
    @ObservationIgnored private var facialMocapLastValues: [Float] = Array(repeating: 0, count: 12)
    @ObservationIgnored private var blendShapeResampler: TrackingResampler
    @ObservationIgnored private var perfectSyncResampler: TrackingResampler
    @ObservationIgnored private let smoothingHolder: SmoothingHolder
    private static let queue = DispatchQueue(label: "com.github.tattn.vcam.facialmocapreceiver")

    @MainActor public private(set) var connectionStatus = ConnectionStatus.disconnected

    @ObservationIgnored private var shouldAutoReconnect = true
    @ObservationIgnored private var lastConnectedIP: String?
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?

    private static let dataTimeoutSeconds: UInt64 = 2

    private final class SmoothingHolder: @unchecked Sendable {
        var smoothing: TrackingSmoothing
        init(_ smoothing: TrackingSmoothing) { self.smoothing = smoothing }
    }

    enum ReceiverResult {
        case success
        case cancel
        case error(any Error)
    }

    public init(smoothing: TrackingSmoothing) {
        let holder = SmoothingHolder(smoothing)
        self.smoothingHolder = holder
        let settingsProvider: @Sendable () -> TrackingResampler.Settings = {
            holder.smoothing.settings()
        }

        blendShapeResampler = TrackingResampler(label: "facial-mocap-blendshape", settingsProvider: settingsProvider) { values in
            UniBridge.shared.receiveVCamBlendShape(values)
        }

        perfectSyncResampler = TrackingResampler(label: "facial-mocap-perfectsync", settingsProvider: settingsProvider) { values in
            UniBridge.shared.receivePerfectSync(values)
        }
    }

    @MainActor
    public func connect(ip: String) async throws {
        await stopInternal()
        shouldAutoReconnect = true
        lastConnectedIP = ip

#if FEATURE_3
        let port = NWEndpoint.Port(integerLiteral: 49983)
#else
        let port = NWEndpoint.Port(integerLiteral: 49984)
#endif

        try await startServer(port: port) { @Sendable [weak self] result in
            switch result {
            case .success: ()
            case .cancel, .error:
                Task { @MainActor in
                    await self?.handleDisconnection()
                }
            }
        }

        requestConnection(ip: ip, port: port) { @Sendable [weak self] result in
            switch result {
            case .success: ()
            case .cancel, .error:
                Task { @MainActor in
                    await self?.handleDisconnection()
                }
            }
        }
    }

    @MainActor
    public func stop() async {
        shouldAutoReconnect = false
        await stopInternal()
    }

    @MainActor
    private func stopInternal() async {
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

        stopResamplers()
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
        guard connectionStatus == .connected, shouldAutoReconnect, let ip = lastConnectedIP else { return }
        await stopInternal()
        do {
            try await connect(ip: ip)
        } catch {
            Logger.log("Restart failed: \(error.localizedDescription)")
        }
    }

    func updateSmoothing(_ smoothing: TrackingSmoothing) {
        smoothingHolder.smoothing = smoothing
        if !smoothing.isEnabled {
            stopResamplers()
        }
    }

    @MainActor
    private func handleDisconnection() async {
        guard shouldAutoReconnect, let ip = lastConnectedIP else {
            await stopInternal()
            return
        }
        await stopInternal()
        do {
            try await connect(ip: ip)
        } catch {
            Logger.log("Restart failed: \(error.localizedDescription)")
        }
    }

    private func oniFacialMocapReceived(_ data: FacialMocapData) {
        guard Tracking.shared.faceTrackingMethod == .iFacialMocap else { return }

        let smoothingEnabled = smoothingHolder.smoothing.isEnabled
        if UniBridge.shared.hasPerfectSyncBlendShape {
            let perfectSync = data.perfectSync(useEyeTracking: Tracking.shared.useEyeTracking)
            if smoothingEnabled {
                perfectSyncResampler.push(perfectSync)
            } else {
                UniBridge.shared.receivePerfectSync(perfectSync)
            }
        } else {
            let blendShape = data.vcamHeadTransform(useEyeTracking: Tracking.shared.useEyeTracking)
            facialMocapLastValues = vDSP.linearInterpolate(
                facialMocapLastValues,
                blendShape,
                using: 0.5
            )

            if smoothingEnabled {
                blendShapeResampler.push(facialMocapLastValues)
            } else {
                UniBridge.shared.receiveVCamBlendShape(facialMocapLastValues)
            }
        }
    }

    func stopResamplers() {
        blendShapeResampler.stop()
        perfectSyncResampler.stop()
    }
}

private extension NWConnection {
    func receiveData(
        with oniFacialMocapReceived: @escaping @Sendable (FacialMocapData) -> Void,
        onDataReceived: @escaping @Sendable () -> Void
    ) {
        receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] content, contentContext, isComplete, error in
            defer {
                self?.receiveData(with: oniFacialMocapReceived, onDataReceived: onDataReceived)
            }

            guard error == nil,
                  let content,
                  let rawData = String(data: content, encoding: .utf8),
                  let mocapData = FacialMocapData(rawData: rawData) else {
                return
            }
            onDataReceived()
            oniFacialMocapReceived(mocapData)
        }
    }
}

extension FacialMocapReceiver {
    @MainActor
    private func startServer(port: NWEndpoint.Port, completion: @escaping @Sendable (ReceiverResult) -> Void) async throws {
        connectionStatus = .connecting

        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true

        let listener = try NWListener(using: parameters, on: port)
        self.listener = listener

        listener.stateUpdateHandler = { newState in
            switch newState {
            case .failed(let error):
                completion(.error(error))
            case .cancelled:
                completion(.cancel)
            default: ()
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.connection = connection
            connection.stateUpdateHandler = { [weak self] state in
                 Task { @MainActor [weak self] in
                     guard let self else { return }
                     switch state {
                     case .setup, .preparing: ()
                     case .waiting(let error):
                         Logger.log("Connection waiting: \(error.localizedDescription)")
                         if case .posix(let posixError) = error, posixError == .ECONNREFUSED {
                             try? await Task.sleep(nanoseconds: NSEC_PER_SEC * 2)
                             try? await self.startServer(port: port, completion: completion)
                         }
                     case .ready:
                         Logger.log("Connection ready")
                         self.connectionStatus = .connected
                         self.resetTimeoutTimer()
                         connection.receiveData(with: { [weak self] data in
                             self?.oniFacialMocapReceived(data)
                         }, onDataReceived: { @Sendable [weak self] in
                             Task { @MainActor in
                                 self?.resetTimeoutTimer()
                             }
                         })
                     case .cancelled:
                         Logger.log("Connection cancelled")
                         await self.handleDisconnection()
                     case .failed(let error):
                         Logger.log("Connection failed: \(error.localizedDescription)")
                         await self.handleDisconnection()
                     @unknown default: ()
                     }
                }
            }

            connection.start(queue: Self.queue)
        }
        listener.start(queue: Self.queue)
    }
}

extension FacialMocapReceiver {
    private func requestConnection(ip: String, port: NWEndpoint.Port, completion: @escaping @Sendable (ReceiverResult) -> Void) {
        @Sendable func retry(completion: @escaping @Sendable (ReceiverResult) -> Void) {
            guard self.listener != nil else {
                completion(.cancel)
                return
            }
            Self.queue.asyncAfter(deadline: .now() + 2) { [self] in
                self.requestConnection(ip: ip, port: port, completion: completion)
            }
        }

        let connection = NWConnection(host: NWEndpoint.Host(ip), port: port, using: .udp)
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .setup, .preparing: ()
            case .waiting(let error):
                if case .posix(let posixError) = error, posixError == .ECONNREFUSED {
                    retry(completion: completion)
                }
            case .ready:
                self?.sendStartToken(connection: connection) { error in
                    if let error {
                        completion(.error(error))
                    } else {
                        completion(.success)
                    }
                }
            case .failed, .cancelled:
                retry(completion: completion)
            @unknown default: ()
            }
        }
        connection.start(queue: Self.queue)
    }

    private func sendStartToken(connection: NWConnection, completion: @escaping @Sendable ((any Error)?) -> Void) {
        let token = "iFacialMocap_sahuasouryya9218sauhuiayeta91555dy3719|sendDataVersion=v2".data(using: .utf8)
        connection.send(content: token, completion: .contentProcessed { error in
            completion(error)
        })
    }
}
