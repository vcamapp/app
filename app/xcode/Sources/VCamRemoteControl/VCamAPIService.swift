import Foundation
import VCamBridge
import VCamControl
import VCamData
import VCamEntity

/// Implements the public API on top of the Control Layer. The transport
/// layer creates one instance per connection so that event subscriptions
/// stay per-connection.
///
/// Witnesses carry their own `@MainActor` because the `@concurrent` inferred
/// from the requirements overrides the type-level annotation.
@MainActor
package struct VCamAPIService: VCamHandler {
    package let connectionID: UUID

    private let modelManager: ModelManager
    private let motionLibrary: MotionLibrary
    private let uniState: UniState
    private let eventPublisher: EventPublisher
    private let importManager: AvatarImportManager

    package init(
        connectionID: UUID,
        modelManager: ModelManager = .shared,
        motionLibrary: MotionLibrary = .shared,
        uniState: UniState = .shared,
        eventPublisher: EventPublisher = .shared,
        importManager: AvatarImportManager = .shared
    ) {
        self.connectionID = connectionID
        self.modelManager = modelManager
        self.motionLibrary = motionLibrary
        self.uniState = uniState
        self.eventPublisher = eventPublisher
        self.importManager = importManager
    }

    @MainActor
    package func appGetInfo() async throws -> AppGetInfoResult {
        var capabilities = ["avatar", "motion", "expression", "scene", "camera", "subtitle", "events"]
#if FEATURE_3
        capabilities.append("vrma")
        capabilities.append("avatarImport")
#endif
        return AppGetInfoResult(
            apiVersion: APISpecification.apiVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            capabilities: capabilities
        )
    }

    @MainActor
    package func stateGet() async throws -> StateGetResult {
        StateGetResult(
            avatarId: modelManager.lastLoadedModelId,
            expressionName: uniState.currentExpressionName,
            playingMotionIds: uniState.isMotionPlaying.filter(\.value).keys.sorted()
        )
    }

    @MainActor
    package func avatarList() async throws -> [Avatar] {
        modelManager.modelItems.map { Avatar(id: $0.id, name: $0.model.localizedName) }
    }

    @MainActor
    package func avatarLoad(avatarId: UUID) async throws -> Bool {
        guard let item = modelManager.modelItems.find(byId: avatarId), item.status == .valid else {
            throw VCamError.avatarNotFound(data: .errorCode("avatar_not_found"))
        }
        try AvatarControl.load(item, modelManager: modelManager)
        return true
    }

    @MainActor
    package func avatarImportBegin(filename: String) async throws -> AvatarImportBeginResult {
#if FEATURE_3
        do {
            let importId = try importManager.begin(filename: filename, connectionID: connectionID)
            return AvatarImportBeginResult(importId: importId)
        } catch {
            throw VCamError.importFailed(data: .errorCode("import_failed"))
        }
#else
        throw VCamError.unsupportedOperation(data: .errorCode("unsupported_operation"))
#endif
    }

    @MainActor
    package func avatarImportCommit(importId: UUID, load: Bool?) async throws -> AvatarImportCommitResult {
        do {
            let avatarId = try await importManager.commit(
                importId: importId,
                connectionID: connectionID,
                load: load ?? false,
                modelManager: modelManager
            )
            return AvatarImportCommitResult(avatarId: avatarId)
        } catch AvatarImportManagerError.importNotFound {
            throw VCamError.importNotFound(data: .errorCode("import_not_found"))
        } catch AvatarImportManagerError.invalidModel {
            throw VCamError.invalidVrm(data: .errorCode("invalid_vrm"))
        } catch {
            throw VCamError.importFailed(data: .errorCode("import_failed"))
        }
    }

    @MainActor
    package func avatarImportCancel(importId: UUID) async throws -> Bool {
        do {
            try importManager.cancel(importId: importId, connectionID: connectionID)
            return true
        } catch {
            throw VCamError.importNotFound(data: .errorCode("import_not_found"))
        }
    }

    @MainActor
    package func expressionList() async throws -> [Expression] {
        uniState.expressions.map { Expression(name: $0.name) }
    }

    @MainActor
    package func expressionSet(name: String) async throws -> Bool {
        guard uniState.expressions.contains(where: { $0.name == name }) else {
            throw VCamError.expressionNotFound(data: .errorCode("expression_not_found"))
        }
        ExpressionControl.apply(name: name)
        return true
    }

    @MainActor
    package func motionList() async throws -> [Motion] {
        motionLibrary.allMotions.map {
            Motion(
                id: $0.id,
                isLoop: motionLibrary.isLoopEnabled(for: $0.id, trigger: .api),
                name: $0.displayName
            )
        }
    }

    @MainActor
    package func motionPlay(motionId: String, loop: Bool?) async throws -> Bool {
        guard motionLibrary.allMotions.contains(where: { $0.id == motionId }) else {
            throw VCamError.motionNotFound(data: .errorCode("motion_not_found"))
        }
        MotionControl.play(id: motionId, isLoop: loop ?? motionLibrary.isLoopEnabled(for: motionId, trigger: .api))
        return true
    }

    @MainActor
    package func motionStop(motionId: String) async throws -> Bool {
        guard motionLibrary.allMotions.contains(where: { $0.id == motionId }) else {
            throw VCamError.motionNotFound(data: .errorCode("motion_not_found"))
        }
        MotionControl.stop(id: motionId)
        return true
    }

    @MainActor
    package func sceneGet() async throws -> Scene {
        guard let scene = SceneControl.provider?.activeScene else {
            throw VCamError.notReady(data: .errorCode("not_ready"))
        }
        return Scene(id: Int(scene.id), name: scene.name)
    }

    @MainActor
    package func sceneLoad(sceneId: Int) async throws -> Bool {
        guard let provider = SceneControl.provider else {
            throw VCamError.notReady(data: .errorCode("not_ready"))
        }
        guard let id = Int32(exactly: sceneId), provider.sceneList.contains(where: { $0.id == id }) else {
            throw VCamError.sceneNotFound(data: .errorCode("scene_not_found"))
        }
        try await provider.loadScene(id: id)
        return true
    }

    @MainActor
    package func cameraReset() async throws -> Bool {
        CameraControl.resetCamera()
        return true
    }

    @MainActor
    package func subtitleSet(text: String) async throws -> Bool {
        uniState.subtitle = text
        return true
    }

    @MainActor
    package func subtitleClear() async throws -> Bool {
        uniState.subtitle = ""
        return true
    }

    @MainActor
    package func eventsSubscribe(events: [String]?) async throws -> Bool {
        eventPublisher.subscribe(id: connectionID, events: events)
        return true
    }

    @MainActor
    package func rpcDiscover() async throws -> [String: JSONValue] {
        try JSONDecoder().decode([String: JSONValue].self, from: APISpecification.data)
    }
}

private extension JSONValue {
    /// The `error.data` payload carrying the stable string identifier
    static func errorCode(_ code: String) -> JSONValue {
        .object(["code": .string(code)])
    }
}
