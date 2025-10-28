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

@Observable
public final class FacialMocapReceiver {
    @ObservationIgnored private var listener: NWListener?
    @ObservationIgnored private var connection: NWConnection?
    @ObservationIgnored private var facialMocapLastValues: [Float] = Array(repeating: 0, count: 12)
    private static let queue = DispatchQueue(label: "com.github.tattn.vcam.facialmocapreceiver")

    @MainActor public private(set) var connectionStatus = ConnectionStatus.disconnected


    public enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
    }

    enum ReceiverResult {
        case success
        case cancel
        case error(any Error)
    }

    public init() {}

    @MainActor
    public func connect(ip: String) async throws {
        await stop()

        let port = NWEndpoint.Port(integerLiteral: 49983)

        try await startServer(port: port) { [weak self] result in
            switch result {
            case .success: ()
            case .cancel, .error:
                self?.stopAsync()
            }
        }

        requestConnection(ip: ip, port: port) { [weak self] result in
            switch result {
            case .success: ()
            case .cancel, .error:
                self?.stopAsync()
            }
        }
    }

    @MainActor
    public func stop() async {
        guard let listener = listener else { return }
        listener.stateUpdateHandler = nil
        listener.newConnectionHandler = nil
        listener.cancel()
        self.listener = nil

        connection?.cancel()
        connection = nil
        connectionStatus = .disconnected
    }

    private func stopAsync() {
        Task {
            await self.stop()
        }
    }

    private func oniFacialMocapReceived(_ data: FacialMocapData) {
        guard Tracking.shared.faceTrackingMethod == .iFacialMocap else { return }
        if UniBridge.shared.hasPerfectSyncBlendShape {
            UniBridge.shared.receivePerfectSync(data.perfectSync(useEyeTracking: Tracking.shared.useEyeTracking))
        } else {
            facialMocapLastValues = vDSP.linearInterpolate(facialMocapLastValues, data.vcamHeadTransform(useEyeTracking: Tracking.shared.useEyeTracking), using: 0.5)
            UniBridge.shared.receiveVCamBlendShape(facialMocapLastValues)
        }
    }
}

private extension NWConnection {
    func receiveData(with oniFacialMocapReceived: @escaping (FacialMocapData) -> Void) {
        receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] content, contentContext, isComplete, error in
            defer {
                self?.receiveData(with: oniFacialMocapReceived)
            }

            guard error == nil,
                  let content,
                  let rawData = String(data: content, encoding: .utf8),
                  let mocapData = FacialMocapData(rawData: rawData) else {
                return
            }

            oniFacialMocapReceived(mocapData)
        }
    }
}

extension FacialMocapReceiver {
    @MainActor
    private func startServer(port: NWEndpoint.Port, completion: @escaping (ReceiverResult) -> Void) async throws {
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
                         if case .posix(let posixError) = error, posixError == .ECONNREFUSED {
                             try? await Task.sleep(nanoseconds: NSEC_PER_SEC * 2)
                             try? await self.startServer(port: port, completion: completion)
                         }
                     case .ready:
                         self.connectionStatus = .connected
                         connection.receiveData(with: self.oniFacialMocapReceived)
                     case .cancelled:
                         self.stopAsync()
                     case .failed:
                         try? await self.startServer(port: port, completion: completion)
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
    private func requestConnection(ip: String, port: NWEndpoint.Port, completion: @escaping (ReceiverResult) -> Void) {
        func retry(completion: @escaping (ReceiverResult) -> Void) {
            guard listener != nil else {
                completion(.cancel)
                return
            }
            Self.queue.asyncAfter(deadline: .now() + 2) {
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

    private func sendStartToken(connection: NWConnection, completion: @escaping ((any Error)?) -> Void) {
        let token = "iFacialMocap_sahuasouryya9218sauhuiayeta91555dy3719|sendDataVersion=v2".data(using: .utf8)
        connection.send(content: token, completion: .contentProcessed { error in
            completion(error)
        })
    }
}
