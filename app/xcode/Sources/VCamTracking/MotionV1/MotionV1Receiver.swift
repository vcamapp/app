import Foundation

@MainActor
final class MotionV1Receiver {
    /// `handledV1`: face is fully accepted here (session/sequence verified);
    /// hands is only shape-validated and forwarded — 
    /// `V1HandPacketState` owns the final session/sequence decision.
    enum ReceiveResult { case handledV1, rejectedV1, notV1 }
    private var faceSequence = MotionSequenceState()
    private let onFace: @MainActor (VCamMotion) -> Void
    private let onHands: @MainActor (Data) -> Void

    init(onFace: @escaping @MainActor (VCamMotion) -> Void,
         onHands: @escaping @MainActor (Data) -> Void) {
        self.onFace = onFace
        self.onHands = onHands
    }

    func resetForNewConnection() {
        faceSequence.reset()
    }

    func receive(_ data: Data) -> ReceiveResult {
        do {
            guard let header = try MotionPacketV1Decoder.headerIfV1(data) else { return .notV1 }
            switch header.type {
            case .face:
                guard faceSequence.canAccept(sessionID: header.sessionID, sequence: header.sequence) else { return .rejectedV1 }
                let face = try MotionPacketV1Decoder.decodeFace(data, header: header)
                faceSequence.commit(sessionID: header.sessionID, sequence: header.sequence)
                onFace(face)
                return .handledV1
            case .hands:
                try MotionPacketV1Decoder.validateHandsPacket(data, header: header)
                onHands(data)
                return .handledV1
            }
        } catch {
            // Invalid packets are discarded.
            return .rejectedV1
        }
    }
}
