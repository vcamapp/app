import VCamControl
import VCamEntity
import VCamTracking

struct TrackingSourceProvider: TrackingControlling {
    var sources: [TrackingControl.Source] {
        let tracking = Tracking.shared
        var sources: [TrackingControl.Source] = [
            .init(id: "vcamMotion", status: tracking.vcamMotionReceiver.connectionStatus),
            .init(id: "iFacialMocap", status: tracking.iFacialMocapReceiver.connectionStatus),
        ]
        if RenderingFeature.supported.contains(.vmcProtocol) {
            sources.append(.init(id: "vmcProtocol", status: tracking.vmcProtocolReceiver.connectionStatus))
        }
        return sources
    }
}
