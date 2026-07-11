import Foundation
import VCamEntity
import struct SwiftUI.Image

public struct VCamWaitAction: VCamAction {
    public init(configuration: VCamWaitActionConfiguration) {
        self.configuration = configuration
    }

    public var configuration: VCamWaitActionConfiguration
    public var name: String { String(localized: .wait) }
    public var icon: Image { Image(systemName: "timer") }

    @MainActor
    public func callAsFunction(context: VCamActionContext) async throws {
        try await Task.sleep(nanoseconds: UInt64(TimeInterval(NSEC_PER_SEC) * configuration.duration))
    }
}
