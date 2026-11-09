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

    /// Where the camera is, in the engine's scene space: the position in meters and Euler angles in
    /// degrees applied in z, x, y order for 3D, and the orthographic zoom for 2D. The scene stores the same values
    public struct View: Sendable, Equatable {
        public var position: SIMD3<Float>
        public var rotation: SIMD3<Float>
        public var zoom: Float

        public init(position: SIMD3<Float>, rotation: SIMD3<Float>, zoom: Float) {
            self.position = position
            self.rotation = rotation
            self.zoom = zoom
        }

        /// Each angle turns the short way round, and the zoom changes by a steady ratio as an adjustment does
        public func interpolated(to target: Self, progress: Float) -> Self {
            let turn = target.rotation - rotation
            return .init(
                position: position + (target.position - position) * progress,
                rotation: rotation + SIMD3(Self.shortTurn(turn.x), Self.shortTurn(turn.y), Self.shortTurn(turn.z)) * progress,
                zoom: zoom * pow(target.zoom / zoom, progress)
            )
        }

        private static func shortTurn(_ degrees: Float) -> Float {
            let turn = (degrees + 180).truncatingRemainder(dividingBy: 360)
            return (turn < 0 ? turn + 360 : turn) - 180
        }
    }

    private static let animationSlot = AnimationSlot()

    /// The engine answers with the camera on screen, which a reset or a drag may have moved since the scene was saved
    public static var view: View {
        let values: [Float] = UniBridge.shared.arrayMapper.get(.objectAvatarTransform, size: UniBridge.ArrayType.objectAvatarTransform.elementCount)
        guard values.count == UniBridge.ArrayType.objectAvatarTransform.elementCount else {
            return .init(position: .zero, rotation: .zero, zoom: 1)
        }
        return .init(position: SIMD3(values[0], values[1], values[2]), rotation: SIMD3(values[3], values[4], values[5]), zoom: values[6])
    }

    /// Saves the result in the scene when done. Finishes when the camera is there, or when
    /// another move takes over.
    public static func set(_ view: View, animation: ControlAnimation? = nil) async {
        guard let animation else {
            animationSlot.cancel()
            send(view)
            UniBridge.cameraControl(.commit)
            return
        }

        let start = Self.view
        let finished = await animationSlot.run(animation) { progress in
            send(start.interpolated(to: view, progress: Float(progress)))
        }
        if finished {
            UniBridge.cameraControl(.commit)
        }
    }

    private static func send(_ view: View) {
        UniBridge.shared.objectAvatarTransform([
            view.position.x, view.position.y, view.position.z,
            view.rotation.x, view.rotation.y, view.rotation.z,
            view.zoom,
        ])
    }

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
