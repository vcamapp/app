//
//  FacialMocapReceiver.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/01/02.
//

import Network
import Combine

public final class FacialMocapReceiver: ObservableObject {
    public static let shared = FacialMocapReceiver()

    private var listener: NWListener?
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.github.tattn.vcam.facialmocapreceiver")

    @MainActor @Published public private(set) var connectionStatus = ConnectionStatus.disconnected

    public enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
    }

    enum ReceiverResult {
        case success
        case cancel
        case error(Error)
    }

    @MainActor
    public func connect(ip: String, avatar: Avatar) async throws {
        await stop()

        let port = NWEndpoint.Port(integerLiteral: 49983)

        try await startServer(port: port, avatar: avatar) { result in
            switch result {
            case .success: ()
            case .cancel, .error:
                Self.shared.stopAsync()
            }
        }

        requestConnection(ip: ip, port: port) { result in
            switch result {
            case .success: ()
            case .cancel, .error:
                Self.shared.stopAsync()
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
            await Self.shared.stop()
        }
    }

    private func receiveData(to avatar: Avatar) {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 8192) { content, contentContext, isComplete, error in
            defer {
                Self.shared.receiveData(to: avatar)
            }

            guard error == nil,
                  let content,
                  let rawData = String(data: content, encoding: .utf8),
                  let mocapData = FacialData.FacialMocap(rawData: rawData) else {
                return
            }

            avatar.apply(.facialMocap(mocapData))
        }
    }
}

extension FacialMocapReceiver {
    @MainActor
    private func startServer(port: NWEndpoint.Port, avatar: Avatar, completion: @escaping (ReceiverResult) -> Void) async throws {
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
        listener.newConnectionHandler = { connection in
            Self.shared.connection = connection
            connection.stateUpdateHandler = { state in
                 Task { @MainActor in
                    switch state {
                    case .setup, .preparing: ()
                    case .waiting(let error):
                        if case .posix(let posixError) = error, posixError == .ECONNREFUSED {
                            try? await Task.sleep(nanoseconds: NSEC_PER_SEC * 2)
                            try? await Self.shared.startServer(port: port, avatar: avatar, completion: completion)
                        }
                    case .ready:
                        Self.shared.connectionStatus = .connected
                        Self.shared.receiveData(to: avatar)
                    case .cancelled:
                        Self.shared.stopAsync()
                    case .failed:
                        try? await Self.shared.startServer(port: port, avatar: avatar, completion: completion)
                    @unknown default: ()
                    }
                }
            }

            connection.start(queue: Self.shared.queue)
        }
        listener.start(queue: queue)
    }
}

extension FacialMocapReceiver {
    private func requestConnection(ip: String, port: NWEndpoint.Port, completion: @escaping (ReceiverResult) -> Void) {
        func retry(completion: @escaping (ReceiverResult) -> Void) {
            guard Self.shared.listener != nil else {
                completion(.cancel)
                return
            }
            Self.shared.queue.asyncAfter(deadline: .now() + 2) {
                Self.shared.requestConnection(ip: ip, port: port, completion: completion)
            }
        }

        let connection = NWConnection(host: NWEndpoint.Host(ip), port: port, using: .udp)
        connection.stateUpdateHandler = { state in
            switch state {
            case .setup, .preparing: ()
            case .waiting(let error):
                if case .posix(let posixError) = error, posixError == .ECONNREFUSED {
                    retry(completion: completion)
                }
            case .ready:
                Self.shared.sendStartToken(connection: connection) { error in
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
        connection.start(queue: Self.shared.queue)
    }

    private func sendStartToken(connection: NWConnection, completion: @escaping (Error?) -> Void) {
        let token = "iFacialMocap_sahuasouryya9218sauhuiayeta91555dy3719|sendDataVersion=v2".data(using: .utf8)
        connection.send(content: token, completion: .contentProcessed { error in
            completion(error)
        })
    }
}
