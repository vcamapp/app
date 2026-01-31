import Foundation
import struct AVFAudio.AudioDeviceID

public struct AudioDevice: Hashable, Identifiable, Sendable {
    public init(id: AudioDeviceID, uid: String) {
        self.id = id
        self.uid = uid
    }

    public let id: AudioDeviceID
    public let uid: String
}
