import Foundation
import VCamBridge

@MainActor
public enum CameraControl {
    /// Amounts are relative to where the camera is. Pan and orbit are fractions of the output
    /// height, and zoom is a magnification: 2 shows the avatar twice as large
    public struct Adjustment: Sendable {
        public var panX: Float
        public var panY: Float
        public var orbitX: Float
        public var orbitY: Float
        public var zoom: Float

        public init(panX: Float = 0, panY: Float = 0, orbitX: Float = 0, orbitY: Float = 0, zoom: Float = 1) {
            self.panX = panX
            self.panY = panY
            self.orbitX = orbitX
            self.orbitY = orbitY
            self.zoom = zoom
        }

        fileprivate func scaled(by scale: Float) -> Self {
            // Equal steps of a magnification are ratios, so it looks steady on the way
            .init(panX: panX * scale, panY: panY * scale, orbitX: orbitX * scale, orbitY: orbitY * scale, zoom: pow(zoom, scale))
        }
    }

    private static let animationSlot = AnimationSlot()

    public static func resetCamera() {
        animationSlot.cancel()
        UniBridge.shared.resetCamera()
    }

    /// Saves the result in the scene when done. Finishes when the camera has moved, or when
    /// another adjustment takes over.
    public static func adjust(_ adjustment: Adjustment, animation: ControlAnimation? = nil) async {
        guard let animation else {
            animationSlot.cancel()
            apply(adjustment)
            UniBridge.cameraControl(.commit)
            return
        }

        // The engine takes amounts relative to where the camera is, so each frame sends what it adds
        var applied: Float = 0
        let finished = await animationSlot.run(animation) { progress in
            let target = Float(progress)
            apply(adjustment.scaled(by: target - applied))
            applied = target
        }
        if finished {
            UniBridge.cameraControl(.commit)
        }
    }

    private static func apply(_ adjustment: Adjustment) {
        if adjustment.panX != 0 || adjustment.panY != 0 {
            UniBridge.cameraControl(.pan, dx: adjustment.panX, dy: adjustment.panY)
        }
        if adjustment.orbitX != 0 || adjustment.orbitY != 0 {
            UniBridge.cameraControl(.orbit, dx: adjustment.orbitX, dy: adjustment.orbitY)
        }
        if adjustment.zoom != 1 {
            UniBridge.cameraControl(.magnify, dx: adjustment.zoom)
        }
    }
}
