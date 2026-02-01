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
import os

@Observable
@MainActor
public final class FacialMocapReceiver {
    @ObservationIgnored private var listener: NWListener?
    @ObservationIgnored private var connection: NWConnection?
    @ObservationIgnored private var facialMocapLastValues: [Float] = Array(repeating: 0, count: 12)
    @ObservationIgnored private var blendShapeResampler: TrackingResampler
    @ObservationIgnored private var perfectSyncResampler: TrackingResampler
    @ObservationIgnored private let smoothingLock: OSAllocatedUnfairLock<TrackingSmoothing>
    nonisolated private static let queue = DispatchQueue(label: "com.github.tattn.vcam.facialmocapreceiver")

    public private(set) var connectionStatus = ConnectionStatus.disconnected

    @ObservationIgnored private var shouldAutoReconnect = true
    @ObservationIgnored private var lastConnectedIP: String?
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?

    private static let dataTimeoutSeconds: UInt64 = 2

    enum ReceiverResult {
        case success
        case cancel
        case error(any Error)
    }

    public init(smoothing: TrackingSmoothing) {
        self.smoothingLock = OSAllocatedUnfairLock(initialState: smoothing)
        let settingsProvider: @Sendable () -> TrackingResampler.Settings = { [smoothingLock] in
            smoothingLock.withLock { $0.settings() }
        }

        blendShapeResampler = TrackingResampler(label: "facial-mocap-blendshape", settingsProvider: settingsProvider) { @MainActor values in
            UniBridge.shared.receiveVCamBlendShape(values)
        }

        perfectSyncResampler = TrackingResampler(label: "facial-mocap-perfectsync", settingsProvider: settingsProvider) { @MainActor values in
            UniBridge.shared.receivePerfectSync(values)
        }
    }

    public func connect(ip: String) async throws {
        stopInternal()
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

    public func stop() async {
        shouldAutoReconnect = false
        stopInternal()
    }

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

        stopResamplers()
    }

    private func resetTimeoutTimer() {
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: Self.dataTimeoutSeconds * NSEC_PER_SEC)
                Logger.log("Data timeout - resetting listener")
                await self?.handleTimeout()
            } catch {}
        }
    }

    private func handleTimeout() async {
        guard connectionStatus == .connected, shouldAutoReconnect, let ip = lastConnectedIP else { return }
        stopInternal()
        do {
            try await connect(ip: ip)
        } catch {
            Logger.log("Restart failed: \(error.localizedDescription)")
        }
    }

    nonisolated func updateSmoothing(_ smoothing: TrackingSmoothing) {
        smoothingLock.withLock { $0 = smoothing }
        if !smoothing.isEnabled {
            Task { @MainActor in
                stopResamplers()
            }
        }
    }

    private func handleDisconnection() async {
        guard shouldAutoReconnect, let ip = lastConnectedIP else {
            stopInternal()
            return
        }
        stopInternal()
        do {
            try await connect(ip: ip)
        } catch {
            Logger.log("Restart failed: \(error.localizedDescription)")
        }
    }

    private func oniFacialMocapReceived(_ data: FacialMocapData) {
        guard Tracking.shared.faceTrackingMethod == .iFacialMocap else { return }

        let smoothingEnabled = smoothingLock.withLock { $0.isEnabled }
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
            DispatchQueue.runOnMain { [weak self] in
                self?.connection = connection
            }
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
                             DispatchQueue.runOnMain { [weak self] in
                                 self?.oniFacialMocapReceived(data)
                             }
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
    private nonisolated func requestConnection(ip: String, port: NWEndpoint.Port, completion: @escaping @Sendable (ReceiverResult) -> Void) {
        @Sendable func retry(completion: @escaping @Sendable (ReceiverResult) -> Void) {
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

    private nonisolated func sendStartToken(connection: NWConnection, completion: @escaping @Sendable ((any Error)?) -> Void) {
        let token = "iFacialMocap_sahuasouryya9218sauhuiayeta91555dy3719|sendDataVersion=v2".data(using: .utf8)
        connection.send(content: token, completion: .contentProcessed { error in
            completion(error)
        })
    }
}
