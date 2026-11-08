import VCamTrackingCore

/// Tracking sources behind an injected provider: the receivers live in a
/// module this layer does not depend on, so the UI layer registers them at startup.
@MainActor
public enum TrackingControl {
    public struct Source {
        public let id: String
        public let status: ConnectionStatus

        public init(id: String, status: ConnectionStatus) {
            self.id = id
            self.status = status
        }
    }

    /// nil until the UI layer has registered its implementation
    public static var provider: (any TrackingControlling)?
}

@MainActor
public protocol TrackingControlling {
    var sources: [TrackingControl.Source] { get }
}
