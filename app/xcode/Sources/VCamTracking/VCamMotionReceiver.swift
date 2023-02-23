//
//  VCamMotionReceiver.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/01/09.
//

import Network
import Combine
import VCamLogger

public final class VCamMotionReceiver {
    private static let queue = DispatchQueue(label: "com.github.tattn.vcam.vcammotionreceiver")
    private var listener: NWListener?
    private var connection: NWConnection?

    @MainActor @Published public private(set) var connectionStatus = ConnectionStatus.disconnected

    public enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
    }

    public enum Error: Swift.Error {
        case cancelled
    }

    public init() {}

    @MainActor
    public func start(avatar: Avatar) async throws {
        connectionStatus = .connecting
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true

        let listener = try NWListener(using: parameters, on: 34962)
        listener.service = .init(type: "_vcammocap._udp", domain: "local")
        self.listener = listener

        return try await withCheckedThrowingContinuation { continuation in
            listener.stateUpdateHandler = { newState in
                switch newState {
                case .failed(let error):
                    Logger.log(error.localizedDescription)
                    listener.stateUpdateHandler = nil
                    continuation.resume(throwing: error)
                case .cancelled:
                    Logger.log("\(newState)")
                    listener.stateUpdateHandler = nil
                    continuation.resume(throwing: Error.cancelled)
                default: ()
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.connection = connection
                connection.stateUpdateHandler = { [weak self] state in
                     Task { @MainActor in
                        switch state {
                        case .setup, .preparing, .waiting, .cancelled, .failed: ()
                        case .ready:
                            self?.connectionStatus = .connected
                            connection.receiveData(with: avatar)
                        @unknown default: ()
                        }
                    }
                }

                connection.start(queue: Self.queue)
            }
            listener.start(queue: Self.queue)
        }
    }

    @MainActor
    public func stop() async {
        guard let listener = listener else { return }
        listener.cancel()
        self.listener = nil

        connection?.cancel()
        connection = nil
        connectionStatus = .disconnected
    }
}

private extension NWConnection {
    func receiveData(with avatar: Avatar) {
        receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] content, contentContext, isComplete, error in
            defer {
                self?.receiveData(with: avatar)
            }

            guard error == nil,
                  let content,
                  content.count == MemoryLayout<VCamMotion>.size else {
                return
            }
            let mocapData = VCamMotion(rawData: content)
            avatar.onVCamMotionReceived(mocapData)
        }
    }
}
