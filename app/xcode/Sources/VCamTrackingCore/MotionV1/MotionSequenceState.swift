import Foundation

package struct MotionSequenceState: Sendable {
    private(set) var sessionID: UInt32?
    private(set) var sequence: UInt32?

    package mutating func reset() { sessionID = nil; sequence = nil }

    package func canAccept(sessionID: UInt32, sequence: UInt32) -> Bool {
        guard let currentSessionID = self.sessionID else { return true }
        guard currentSessionID == sessionID else { return false }
        guard let current = self.sequence else { return true }
        return sequence != current && sequence &- current < 0x8000_0000
    }

    package mutating func commit(sessionID: UInt32, sequence: UInt32) {
        self.sessionID = sessionID
        self.sequence = sequence
    }
}
