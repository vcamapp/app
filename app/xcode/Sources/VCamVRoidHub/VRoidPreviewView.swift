import QuartzCore
import RealityKit
import SwiftUI
import VRMKit
import VRMRealityKit

/// A lightweight 3D preview of a VRM: a standing pose with drag-to-rotate and
/// spring bone simulation. Rendering fidelity intentionally differs from the
/// app's runtime renderer; this is only for choosing a model
struct VRoidPreviewView: View {
    let modelData: Data
    let onLoadFailed: () -> Void

    @State private var model = VRoidPreviewModel()
    @State private var dragStartYaw: Float?

    var body: some View {
        RealityView { content in
            content.add(model.rootEntity)
            model.sceneSubscription = content.subscribe(to: SceneEvents.Update.self) { _ in
                // RealityKit delivers scene events on the main actor
                MainActor.assumeIsolated {
                    model.update()
                }
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    let startYaw = dragStartYaw ?? model.yaw
                    dragStartYaw = startYaw
                    model.yaw = startYaw + Float(value.translation.width) * .pi / 180
                }
                .onEnded { _ in
                    dragStartYaw = nil
                }
        )
        .task {
            do {
                try await model.load(data: modelData)
            } catch {
                onLoadFailed()
            }
        }
    }
}

@MainActor
private final class VRoidPreviewModel {
    let rootEntity = Entity()

    var yaw: Float = 0 {
        didSet { applyRotation() }
    }

    private var vrmEntity: VRMEntity?
    private let modelPivot = Entity()
    private var initialYaw: Float = 0

    /// Drives spring bones etc. only while the scene actually renders
    var sceneSubscription: EventSubscription?

    func load(data: Data) async throws {
        // Parsing a model of tens of megabytes must not block the UI;
        // only the entity construction needs the main actor
        let vrm = try await Self.parse(data)
        let loader = VRMEntityLoader(vrm: vrm)
        let vrmEntity = try loader.loadEntity()

        // Face the model toward the viewer (VRM 0.x models face +Z)
        initialYaw = if case .v0 = vrmEntity.vrm { Float.pi } else { 0 }

        applyAPose(to: vrmEntity)

        // A key light from the viewer's side keeps the toon textures from
        // looking dim under the default environment lighting
        let keyLight = Entity()
        keyLight.components.set(DirectionalLightComponent(color: .white, intensity: 1000))
        keyLight.orientation = simd_quatf(angle: -20 * .pi / 180, axis: SIMD3<Float>(1, 0, 0))
        rootEntity.addChild(keyLight)

        // Rotate around the center of the model, not its root bone, so
        // off-center or non-humanoid shapes stay in place while dragging
        let bounds = vrmEntity.entity.visualBounds(relativeTo: vrmEntity.entity)
        let center = (bounds.min + bounds.max) / 2
        vrmEntity.entity.position = SIMD3<Float>(-center.x, 0, -center.z)
        modelPivot.addChild(vrmEntity.entity)
        rootEntity.addChild(modelPivot)

        // Frame the whole model with a small margin. The vertical fit uses the
        // height (fieldOfViewInDegrees is the vertical field of view) and the
        // horizontal fit uses the largest radius around the rotation axis, so
        // wide models stay inside the view at any drag angle
        let camera = PerspectiveCamera()
        let fieldOfView: Float = 30
        let margin: Float = 1.05
        let halfVertical = tan(fieldOfView / 2 * .pi / 180)
        let halfHorizontal = halfVertical * 3 / 4 // the pane keeps a 3:4 aspect ratio
        let radius = simd_length(SIMD2<Float>(bounds.max.x - bounds.min.x, bounds.max.z - bounds.min.z)) / 2
        let verticalDistance = (bounds.max.y - bounds.min.y) / 2 * margin / halfVertical
        let horizontalDistance = radius * margin / halfHorizontal
        // The model's nearest point comes `radius` closer while rotating
        let distance = max(verticalDistance, horizontalDistance) + radius
        camera.camera.fieldOfViewInDegrees = fieldOfView
        camera.position = SIMD3<Float>(0, (bounds.max.y + bounds.min.y) / 2, distance)
        rootEntity.addChild(camera)

        self.vrmEntity = vrmEntity
        applyRotation()
    }

    func update() {
        vrmEntity?.update(at: CACurrentMediaTime())
    }

    @concurrent
    private nonisolated static func parse(_ data: Data) async throws -> sending VRM {
        try VRMLoader().load(withData: data)
    }

    /// Lowers both arms from the T-pose into an A-pose
    private func applyAPose(to vrmEntity: VRMEntity) {
        if let upperArm = vrmEntity.humanoid.node(for: .leftUpperArm),
           let lowerArm = vrmEntity.humanoid.node(for: .leftLowerArm) {
            lowerArmFromTPose(upperArm: upperArm, lowerArm: lowerArm)
        }
        if let upperArm = vrmEntity.humanoid.node(for: .rightUpperArm),
           let lowerArm = vrmEntity.humanoid.node(for: .rightLowerArm) {
            lowerArmFromTPose(upperArm: upperArm, lowerArm: lowerArm)
        }
    }

    private func lowerArmFromTPose(upperArm: Entity, lowerArm: Entity) {
        // The rotation direction that moves the arm downward depends on which
        // way the arm extends; bone axes differ between VRM 0.x and 1.0 skeletons
        let armDirection = upperArm.convert(position: .zero, from: lowerArm)
        let sign: Float = armDirection.x >= 0 ? -1 : 1
        let rotation = simd_quatf(angle: sign * 60 * .pi / 180, axis: SIMD3<Float>(0, 0, 1))
        upperArm.transform.rotation = upperArm.transform.rotation * rotation
    }

    private func applyRotation() {
        modelPivot.transform.rotation = simd_quatf(angle: initialYaw + yaw, axis: SIMD3<Float>(0, 1, 0))
    }
}
