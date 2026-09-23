import Foundation
import Synchronization
import VCamMotionV1

/// Decodes the framed protocol and keeps the face packets of the current sender session in
/// order. Runs on the receive queue, so the face reaches the resamplers without waiting for
/// the main actor
package final class MotionV1Receiver: Sendable {
    package enum Packet: Sendable {
        /// Fully accepted here (session/sequence verified)
        case face(VCamMotion)
        /// Only shape-validated; `V1HandPacketState` owns the final session/sequence decision
        case hands(Data)
        case rejected
        case notV1
    }

    private let faceSequence = Mutex(MotionSequenceState())

    package init() {}

    package func resetForNewConnection() {
        faceSequence.withLock { $0.reset() }
    }

    package func receive(_ data: Data) -> Packet {
        do {
            guard let header = try MotionPacketV1Decoder.headerIfV1(data) else { return .notV1 }
            switch header.type {
            case .face:
                return try faceSequence.withLock { sequence -> Packet in
                    guard sequence.canAccept(sessionID: header.sessionID, sequence: header.sequence) else { return .rejected }
                    let face = try MotionPacketV1Decoder.decodeFace(data, header: header)
                    sequence.commit(sessionID: header.sessionID, sequence: header.sequence)
                    return .face(face)
                }
            case .hands:
                try MotionPacketV1Decoder.validateHandsPacket(data, header: header)
                return .hands(data)
            }
        } catch {
            // Invalid packets are discarded.
            return .rejected
        }
    }
}
