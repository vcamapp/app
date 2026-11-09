import Foundation
import VCamBridge
import VCamControl
import VCamData
import VCamEntity
import VCamTrackingCore

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
    private let sceneObjects: SceneObjectAPIHandler
    private let motions: MotionAPIHandler

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
        sceneObjects = SceneObjectAPIHandler(connectionID: connectionID, staging: importManager.staging)
        motions = MotionAPIHandler(connectionID: connectionID, library: motionLibrary, staging: importManager.staging)
    }

    @MainActor
    package func appGetInfo() async throws -> AppGetInfoResult {
        var capabilities = ["avatar", "motion", "expression", "scene", "camera", "subtitle", "tracking", "events"]
#if FEATURE_3
        capabilities.append("vrma")
        capabilities.append("avatarImport")
#endif
        if PoseControl.provider != nil {
            capabilities.append("poseEditor")
        }
        if EmojiControl.presentStamp != nil {
            capabilities.append("emoji")
        }
        if SceneObjectControl.provider != nil {
            capabilities.append("sceneObjects")
        }
        if RenderingFeature.supported.contains(.sceneLighting) {
            capabilities.append("sceneLighting")
        }
        if UserDefaults.standard.value(for: .integrationExternalControlFrameCapture) {
            capabilities.append("frameCapture")
        }
        return AppGetInfoResult(
            apiVersion: APISpecification.apiVersion,
            appVersion: Bundle.main.version,
            capabilities: capabilities
        )
    }

    @MainActor
    package func stateGet() async throws -> StateGetResult {
        StateGetResult(
            avatarId: modelManager.lastLoadedModelId,
            expressions: uniState.currentExpressions.map { ExpressionWeight(name: $0.name, weight: $0.weight) },
            playingMotionIds: uniState.isMotionPlaying.filter(\.value).keys.sorted(),
            subtitle: uniState.subtitle
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
        do {
            try await AvatarControl.loadAndWait(item, modelManager: modelManager)
        } catch is ModelLoadError {
            throw VCamError.avatarLoadFailed(data: .errorCode("avatar_load_failed"))
        }
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
        } catch UploadError.importNotFound {
            throw VCamError.importNotFound(data: .errorCode("import_not_found"))
        } catch UploadError.invalidContent {
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
    package func expressionSet(expressions: [ExpressionWeight], duration: Double?, easing: AnimationEasing?) async throws -> Bool {
        var applied: [AppliedExpression] = []
        for expression in expressions {
            // The list's own spelling: names reach the renderer byte for byte, while Swift compares them by canonical equivalence
            guard let known = uniState.expressions.first(where: { $0.name == expression.name }) else {
                throw VCamError.expressionNotFound(data: .errorCode("expression_not_found"))
            }
            guard (0...1).contains(expression.weight) else {
                throw TextStyleMapping.invalidParameter("weight", "expected a number from 0 to 1")
            }
            guard !applied.contains(where: { $0.name == known.name }) else {
                throw TextStyleMapping.invalidParameter("expressions", "expected each name once")
            }
            applied.append(AppliedExpression(name: known.name, weight: expression.weight))
        }
        let animation = try AnimationMapping.animation(duration: duration, easing: easing)
        await ExpressionControl.apply(applied, animation: animation, state: uniState)
        return true
    }

    @MainActor
    package func gazeSet(mode: GazeSetMode, yaw: Double?, pitch: Double?, movesHead: Bool?) async throws -> Bool {
        let target: GazeControl.Target
        switch mode {
        case .auto:
            target = .auto
        case .camera:
            target = .camera
        case .direction:
            let yaw = yaw ?? 0
            let pitch = pitch ?? 0
            guard (-90...90).contains(yaw) else {
                throw TextStyleMapping.invalidParameter("yaw", "expected degrees from -90 to 90")
            }
            guard (-45...45).contains(pitch) else {
                throw TextStyleMapping.invalidParameter("pitch", "expected degrees from -45 to 45")
            }
            target = .direction(yaw: Float(yaw), pitch: Float(pitch))
        }
        GazeControl.look(at: target, movesHead: movesHead ?? true)
        return true
    }

    @MainActor
    package func motionList() async throws -> [Motion] {
        await motions.list()
    }

    @MainActor
    package func motionPlay(motionId: String, loop: Bool?, wait: Bool?) async throws -> Bool {
        guard motionLibrary.allMotions.contains(where: { $0.id == motionId }) else {
            throw VCamError.motionNotFound(data: .errorCode("motion_not_found"))
        }
        let isLoop = loop ?? motionLibrary.isLoopEnabled(for: motionId, trigger: .api)
        MotionControl.play(id: motionId, isLoop: isLoop)
        let isPose = motionLibrary.record(for: motionId)?.isPose ?? false
        if wait == true, !isLoop, !isPose {
            await MotionControl.waitUntilStopped(id: motionId, state: uniState)
        }
        return true
    }

    @MainActor
    package func motionImportBegin(filename: String) async throws -> MotionImportBeginResult {
        MotionImportBeginResult(importId: try motions.beginImport(filename: filename))
    }

    @MainActor
    package func motionImportCommit(importId: UUID, name: String?, loop: Bool?, isPose: Bool?) async throws -> MotionImportCommitResult {
        try await motions.commitImport(importId: importId, name: name, loop: loop, isPose: isPose)
    }

    @MainActor
    package func motionImportCancel(importId: UUID) async throws -> Bool {
        try motions.cancelImport(importId: importId)
        return true
    }

    @MainActor
    package func motionRemove(motionId: String) async throws -> Bool {
        try motions.remove(motionId: motionId)
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
    package func sceneList() async throws -> [Scene] {
        guard let provider = SceneControl.provider else {
            throw VCamError.notReady(data: .errorCode("not_ready"))
        }
        return provider.sceneList.map(Self.scene)
    }

    @MainActor
    package func sceneGet() async throws -> Scene {
        guard let scene = SceneControl.provider?.activeScene else {
            throw VCamError.notReady(data: .errorCode("not_ready"))
        }
        return Self.scene(scene)
    }

    private static func scene(_ scene: SceneControl.Scene) -> Scene {
        Scene(id: Int(scene.id), name: scene.name)
    }

    @MainActor
    package func sceneLoad(sceneId: Int, duration: Double?, easing: AnimationEasing?) async throws -> Bool {
        let animation = try AnimationMapping.animation(duration: duration, easing: easing)
        guard let provider = SceneControl.provider else {
            throw VCamError.notReady(data: .errorCode("not_ready"))
        }
        guard let id = Int32(exactly: sceneId), provider.sceneList.contains(where: { $0.id == id }) else {
            throw VCamError.sceneNotFound(data: .errorCode("scene_not_found"))
        }
        try await SceneControl.loadScene(id: id, animation: animation, on: provider)
        return true
    }

    @MainActor
    package func sceneCreate(name: String?) async throws -> Scene {
        try await withSceneProvider { Self.scene(try await $0.createScene(name: name)) }
    }

    @MainActor
    package func sceneDuplicate(sceneId: Int, name: String?) async throws -> Scene {
        let id = try Self.sceneID(sceneId)
        return try await withSceneProvider { Self.scene(try await $0.duplicateScene(id: id, name: name)) }
    }

    @MainActor
    package func sceneRename(sceneId: Int, name: String) async throws -> Bool {
        let id = try Self.sceneID(sceneId)
        try await withSceneProvider { try $0.renameScene(id: id, name: name) }
        return true
    }

    @MainActor
    package func sceneMove(sceneId: Int, index: Int) async throws -> Bool {
        let id = try Self.sceneID(sceneId)
        try await withSceneProvider { try $0.moveScene(id: id, toIndex: index) }
        return true
    }

    @MainActor
    package func sceneRemove(sceneId: Int) async throws -> Bool {
        let id = try Self.sceneID(sceneId)
        try await withSceneProvider { try await $0.removeScene(id: id) }
        return true
    }

    @MainActor
    package func sceneGetLighting() async throws -> SceneGetLightingResult {
        try Self.requireSceneLighting()
        return try await withSceneProvider { provider in
            SceneGetLightingResult(lighting: provider.lighting.map(SceneLightingMapping.apiLighting))
        }
    }

    @MainActor
    package func sceneSetLighting(lighting: SceneLighting?) async throws -> Bool {
        try Self.requireSceneLighting()
        let lighting = try lighting.map(SceneLightingMapping.lighting)
        try await withSceneProvider { try $0.setLighting(lighting) }
        return true
    }

    private static func requireSceneLighting() throws {
        guard RenderingFeature.supported.contains(.sceneLighting) else {
            throw VCamError.unsupportedOperation(data: .errorCode("unsupported_operation"))
        }
    }

    private static func sceneID(_ value: Int) throws -> Int32 {
        guard let id = Int32(exactly: value) else {
            throw VCamError.sceneNotFound(data: .errorCode("scene_not_found"))
        }
        return id
    }

    private func withSceneProvider<Result>(_ body: (any SceneControlling) async throws -> Result) async throws -> Result {
        guard let provider = SceneControl.provider else {
            throw VCamError.notReady(data: .errorCode("not_ready"))
        }
        do {
            return try await body(provider)
        } catch SceneControlError.notFound {
            throw VCamError.sceneNotFound(data: .errorCode("scene_not_found"))
        } catch SceneControlError.notRemovable {
            throw VCamError.sceneNotRemovable(data: .errorCode("scene_not_removable"))
        }
    }

    @MainActor
    package func canvasGet() async throws -> CanvasGetResult {
        let size = MainTexture.shared.size
        return CanvasGetResult(height: Int(size.height), width: Int(size.width))
    }

    @MainActor
    package func canvasGetBackgroundColor() async throws -> String {
        CanvasColorMapping.hex(uniState.backgroundColor)
    }

    @MainActor
    package func canvasSetBackgroundColor(color: String) async throws -> Bool {
        uniState.backgroundColor = try CanvasColorMapping.color(color)
        return true
    }

    @MainActor
    package func frameCapture(maxWidth: Int?, format: FrameCaptureFormat?) async throws -> FrameCaptureResult {
        guard UserDefaults.standard.value(for: .integrationExternalControlFrameCapture) else {
            throw VCamError.frameCaptureDisabled(data: .errorCode("frame_capture_disabled"))
        }
        if let maxWidth, maxWidth <= 0 {
            throw TextStyleMapping.invalidParameter("maxWidth", "expected a positive number")
        }
        // A change made just before this call is still on its way to the frame: text, for one,
        // re-rasterizes into a new texture, and is missing from the frames until that is done
        try await Task.sleep(for: Self.frameCaptureSettleDelay)
        guard let image = MainTexture.shared.snapshot() else {
            throw VCamError.notReady(data: .errorCode("not_ready"))
        }
        return try await FrameCapture.encode(image, maxWidth: maxWidth, format: format ?? .jpeg)
    }

    private static let frameCaptureSettleDelay = Duration.milliseconds(150)

    // MARK: - Objects

    @MainActor
    package func objectList() async throws -> [ObjectInfo] {
        try await sceneObjects.list()
    }

    @MainActor
    package func objectUpdate(objectId: Int, name: String?, isHidden: Bool?, isLocked: Bool?, placement: ObjectPlacementUpdate?, duration: Double?, easing: AnimationEasing?) async throws -> Bool {
        let animation = try AnimationMapping.animation(duration: duration, easing: easing)
        try await sceneObjects.update(objectId: objectId, name: name, isHidden: isHidden, isLocked: isLocked, placement: placement, animation: animation)
        return true
    }

    @MainActor
    package func objectMove(objectId: Int, index: Int) async throws -> Bool {
        try await sceneObjects.move(objectId: objectId, index: index)
        return true
    }

    @MainActor
    package func objectDuplicate(objectId: Int) async throws -> ObjectDuplicateResult {
        ObjectDuplicateResult(objectId: try await sceneObjects.duplicate(objectId: objectId))
    }

    @MainActor
    package func objectRemove(objectId: Int) async throws -> Bool {
        try await sceneObjects.remove(objectId: objectId)
        return true
    }

    @MainActor
    package func textAdd(text: String, name: String?, preset: String?, style: TextStyle?, placement: ObjectPlacementUpdate?) async throws -> TextAddResult {
        TextAddResult(objectId: try await sceneObjects.addText(text: text, name: name, preset: preset, style: style, placement: placement))
    }

    @MainActor
    package func textGet(objectId: Int) async throws -> TextGetResult {
        try await sceneObjects.getText(objectId: objectId)
    }

    @MainActor
    package func textUpdate(objectId: Int, text: String?, preset: String?, style: TextStyle?) async throws -> Bool {
        try await sceneObjects.updateText(objectId: objectId, text: text, preset: preset, style: style)
        return true
    }

    @MainActor
    package func textListPresets() async throws -> [TextPreset] {
        try await sceneObjects.listTextPresets()
    }

    @MainActor
    package func textListFonts() async throws -> [String] {
        try await sceneObjects.listFonts()
    }

    @MainActor
    package func subtitleGetStyle() async throws -> SubtitleGetStyleResult {
        try await sceneObjects.subtitleStyle()
    }

    @MainActor
    package func subtitleSetStyle(preset: String?, style: TextStyle?, placement: SubtitlePlacement?, duration: Double?, easing: AnimationEasing?) async throws -> Bool {
        let animation = try AnimationMapping.animation(duration: duration, easing: easing)
        try await sceneObjects.setSubtitleStyle(preset: preset, style: style, placement: placement, animation: animation)
        return true
    }

    @MainActor
    package func imageImportBegin(filename: String) async throws -> ImageImportBeginResult {
        ImageImportBeginResult(importId: try sceneObjects.beginImageImport(filename: filename))
    }

    @MainActor
    package func imageImportCommit(importId: UUID, name: String?, placement: ObjectPlacementUpdate?) async throws -> ImageImportCommitResult {
        ImageImportCommitResult(objectId: try await sceneObjects.commitImageImport(importId: importId, name: name, placement: placement))
    }

    @MainActor
    package func imageImportCancel(importId: UUID) async throws -> Bool {
        try sceneObjects.cancelImageImport(importId: importId)
        return true
    }

    @MainActor
    package func videoImportBegin(filename: String) async throws -> VideoImportBeginResult {
        VideoImportBeginResult(importId: try sceneObjects.beginVideoImport(filename: filename))
    }

    @MainActor
    package func videoImportCommit(importId: UUID, name: String?, placement: ObjectPlacementUpdate?, isLooping: Bool?, isMuted: Bool?) async throws -> VideoImportCommitResult {
        try await sceneObjects.commitVideoImport(importId: importId, name: name, placement: placement, isLooping: isLooping, isMuted: isMuted)
    }

    @MainActor
    package func videoImportCancel(importId: UUID) async throws -> Bool {
        try sceneObjects.cancelVideoImport(importId: importId)
        return true
    }

    @MainActor
    package func videoGet(objectId: Int) async throws -> VideoState {
        try await sceneObjects.video(objectId: objectId)
    }

    @MainActor
    package func videoUpdate(objectId: Int, isPlaying: Bool?, time: Double?, isLooping: Bool?, isMuted: Bool?) async throws -> VideoState {
        try await sceneObjects.updateVideo(objectId: objectId, isPlaying: isPlaying, time: time, isLooping: isLooping, isMuted: isMuted)
    }

    @MainActor
    package func webAdd(url: String, name: String?, width: Int?, height: Int?, fps: Int?, placement: ObjectPlacementUpdate?) async throws -> WebAddResult {
        WebAddResult(objectId: try await sceneObjects.addWeb(url: url, name: name, width: width, height: height, fps: fps, placement: placement))
    }

    @MainActor
    package func webUpdate(objectId: Int, url: String?, width: Int?, height: Int?, fps: Int?) async throws -> Bool {
        try await sceneObjects.updateWeb(objectId: objectId, url: url, width: width, height: height, fps: fps)
        return true
    }

    @MainActor
    package func cameraReset() async throws -> Bool {
        CameraControl.resetCamera()
        return true
    }

    @MainActor
    package func cameraAdjust(panX: Double?, panY: Double?, orbitX: Double?, orbitY: Double?, zoom: Double?, duration: Double?, easing: AnimationEasing?) async throws -> Bool {
        let amounts = [panX, panY, orbitX, orbitY].map { $0 ?? 0 }
        guard amounts.allSatisfy(\.isFinite) else {
            throw TextStyleMapping.invalidParameter("camera", "expected finite numbers")
        }
        let zoom = zoom ?? 1
        guard (0.1...10).contains(zoom) else {
            throw TextStyleMapping.invalidParameter("zoom", "expected a magnification from 0.1 to 10")
        }
        let animation = try AnimationMapping.animation(duration: duration, easing: easing)
        let adjustment = CameraControl.Adjustment(panX: Float(amounts[0]), panY: Float(amounts[1]), orbitX: Float(amounts[2]), orbitY: Float(amounts[3]), zoom: Float(zoom))
        await CameraControl.adjust(adjustment, animation: animation)
        return true
    }

    @MainActor
    package func cameraGet() async throws -> CameraView {
        let view = CameraControl.view
        return CameraView(
            position: [view.position.x, view.position.y, view.position.z].map(Double.init),
            rotation: [view.rotation.x, view.rotation.y, view.rotation.z].map(Double.init),
            zoom: Double(view.zoom)
        )
    }

    @MainActor
    package func cameraSet(position: [Double]?, rotation: [Double]?, zoom: Double?, duration: Double?, easing: AnimationEasing?) async throws -> Bool {
        if let zoom, !(0.1...10).contains(zoom) {
            throw TextStyleMapping.invalidParameter("zoom", "expected a zoom from 0.1 to 10")
        }
        let animation = try AnimationMapping.animation(duration: duration, easing: easing)
        var view = CameraControl.view
        if let position {
            view.position = try Self.vector(position, name: "position")
        }
        if let rotation {
            view.rotation = try Self.vector(rotation, name: "rotation")
        }
        if let zoom {
            view.zoom = Float(zoom)
        }
        await CameraControl.set(view, animation: animation)
        return true
    }

    private static func vector(_ values: [Double], name: String) throws -> SIMD3<Float> {
        guard values.count == 3, values.allSatisfy(\.isFinite) else {
            throw TextStyleMapping.invalidParameter(name, "expected three finite numbers")
        }
        return SIMD3(Float(values[0]), Float(values[1]), Float(values[2]))
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
    package func emojiShow(emoji: String) async throws -> Bool {
        guard EmojiControl.presentStamp != nil else {
            throw VCamError.unsupportedOperation(data: .errorCode("unsupported_operation"))
        }
        guard emoji.count == 1, emoji.unicodeScalars.first?.properties.isEmoji == true else {
            throw JSONRPCErrorObject(code: -32602, message: "Invalid parameter \"emoji\": expected a single emoji")
        }
        try EmojiControl.show(emoji)
        return true
    }

    @MainActor
    package func shortcutList() async throws -> [Shortcut] {
        guard let provider = ShortcutControl.provider else {
            throw VCamError.notReady(data: .errorCode("not_ready"))
        }
        return provider.shortcuts.map(Shortcut.init)
    }

    @MainActor
    package func shortcutRun(shortcutId: UUID) async throws -> Bool {
        guard let provider = ShortcutControl.provider else {
            throw VCamError.notReady(data: .errorCode("not_ready"))
        }
        guard let shortcut = provider.shortcuts.first(where: { $0.id == shortcutId }) else {
            throw VCamError.shortcutNotFound(data: .errorCode("shortcut_not_found"))
        }
        do {
            try await provider.perform(shortcut)
        } catch ShortcutControlError.alreadyRunning {
            throw VCamError.shortcutRunning(data: .errorCode("shortcut_running"))
        } catch {
            throw VCamError.shortcutFailed(data: .errorCode("shortcut_failed"))
        }
        return true
    }

    @MainActor
    package func recordingGetState() async throws -> RecordingState {
        guard let provider = RecordingControl.provider else {
            throw VCamError.notReady(data: .errorCode("not_ready"))
        }
        switch provider.state {
        case .idle:
            return RecordingState(status: .idle)
        case .recording(let startedAt):
            return RecordingState(duration: Date.now.timeIntervalSince(startedAt), status: .recording)
        case .finishing:
            return RecordingState(status: .finishing)
        }
    }

    @MainActor
    package func recordingStart() async throws -> Bool {
        guard let provider = RecordingControl.provider else {
            throw VCamError.notReady(data: .errorCode("not_ready"))
        }
        do {
            try await provider.start()
        } catch RecordingControlError.noFolder {
            throw VCamError.recordingFolderNotSet(data: .errorCode("recording_folder_not_set"))
        } catch {
            throw VCamError.recordingFailed(data: .errorCode("recording_failed"))
        }
        return true
    }

    @MainActor
    package func recordingStop() async throws -> Bool {
        guard let provider = RecordingControl.provider else {
            throw VCamError.notReady(data: .errorCode("not_ready"))
        }
        await provider.stop()
        return true
    }

    @MainActor
    package func trackingGetState() async throws -> TrackingGetStateResult {
        guard let provider = TrackingControl.provider else {
            throw VCamError.notReady(data: .errorCode("not_ready"))
        }
        return TrackingGetStateResult(sources: provider.sources.map {
            TrackingSource(id: $0.id, status: Self.trackingStatus($0.status))
        })
    }

    private static func trackingStatus(_ status: ConnectionStatus) -> TrackingSourceStatus {
        switch status {
        case .disconnected: .disconnected
        case .connecting: .connecting
        case .connected: .connected
        }
    }

    // MARK: - Pose

    @MainActor
    package func poseOpen() async throws -> PoseOpenResult {
        try await withPoseEditor { editor in
            let rig = try await editor.open()
            return PoseOpenResult(bones: rig.bones, expressions: rig.expressions, movableBones: rig.movableBones)
        }
    }

    @MainActor
    package func poseGet() async throws -> [JointPose] {
        try await withPoseEditor { editor in
            try editor.currentPose().map(Self.jointPose)
        }
    }

    @MainActor
    package func poseMove(joints: [JointTarget], plantFeet: Bool?) async throws -> [JointPose] {
        let targets = try joints.map { joint in
            PoseControl.JointTarget(bone: joint.name, position: try Self.vector(joint.position, of: "position"))
        }
        return try await withPoseEditor { editor in
            try editor.movePose(targets, plantsFeet: plantFeet ?? true).map(Self.jointPose)
        }
    }

    private static func jointPose(_ joint: PoseControl.JointPose) -> JointPose {
        JointPose(effector: joint.effector.map(components),
                  name: joint.bone,
                  position: joint.position.map(components),
                  rotation: components(joint.rotation))
    }

    @MainActor
    package func poseSet(joints: [JointPose]) async throws -> Bool {
        let pose = try joints.map { joint in
            PoseControl.JointPose(bone: joint.name,
                                  rotation: try Self.vector(joint.rotation, of: "rotation"),
                                  position: try joint.position.map { try Self.vector($0, of: "position") })
        }
        try await withPoseEditor { try $0.setPose(pose) }
        return true
    }

    @MainActor
    package func poseReset(bones: [String]?) async throws -> Bool {
        try await withPoseEditor { try $0.resetPose(bones: bones) }
        return true
    }

    @MainActor
    package func poseExpressionsGet() async throws -> [ExpressionWeight] {
        try await withPoseEditor { editor in
            try editor.currentExpressions().map { ExpressionWeight(name: $0.name, weight: Double($0.weight)) }
        }
    }

    @MainActor
    package func poseExpressionsSet(expressions: [ExpressionWeight]) async throws -> Bool {
        let weights = try expressions.map { expression in
            PoseControl.ExpressionWeight(name: expression.name,
                                         weight: try Self.unitWeight(expression.weight, of: "weight"))
        }
        try await withPoseEditor { try $0.setExpressions(weights) }
        return true
    }

    @MainActor
    package func poseExpressionsReset(names: [String]?) async throws -> Bool {
        try await withPoseEditor { try $0.resetExpressions(names: names) }
        return true
    }

    @MainActor
    package func poseApply() async throws -> Bool {
        try await withPoseEditor { try await $0.applyToAvatar() }
        return true
    }

    @MainActor
    package func poseExport(name: String?, duration: Double?) async throws -> PoseExportResult {
        try await withPoseEditor { editor in
            let data = try editor.exportAnimation(name: name ?? Self.defaultPoseName,
                                                  duration: Float(duration ?? Self.defaultPoseDuration))
            return PoseExportResult(vrma: data.base64EncodedString())
        }
    }

    @MainActor
    package func poseSaveAsMotion(name: String, duration: Double?, loop: Bool?) async throws -> PoseSaveAsMotionResult {
        try await withPoseEditor { editor in
            do {
                return PoseSaveAsMotionResult(motionId: try await editor.addToMotions(
                    name: name,
                    duration: Float(duration ?? Self.defaultPoseDuration),
                    isLoop: loop ?? false
                ))
            } catch let error as PoseControlError {
                throw error
            } catch {
                throw VCamError.importFailed(data: .errorCode("import_failed"))
            }
        }
    }

    @MainActor
    package func poseClose() async throws -> Bool {
        PoseControl.provider?.close()
        return true
    }

    private static let defaultPoseName = "Pose"
    private static let defaultPoseDuration: Double = 2

    /// Whether the editor is open enough to serve a request is the editor's own call,
    /// so every method goes through here.
    private func withPoseEditor<T>(_ body: (any PoseEditing) async throws -> T) async throws -> T {
        guard let editor = PoseControl.provider else {
            throw VCamError.unsupportedOperation(data: .errorCode("unsupported_operation"))
        }
        do {
            return try await body(editor)
        } catch let error as PoseControlError {
            throw Self.poseError(error)
        }
    }

    private static func poseError(_ error: PoseControlError) -> any Error {
        switch error {
        case .editorNotOpen:
            VCamError.poseEditorNotOpen(data: .errorCode("pose_editor_not_open"))
        case .boneNotFound:
            VCamError.boneNotFound(data: .errorCode("bone_not_found"))
        case .boneNotMovable:
            VCamError.boneNotMovable(data: .errorCode("bone_not_movable"))
        case .expressionNotFound:
            VCamError.expressionNotFound(data: .errorCode("expression_not_found"))
        case .avatarUnavailable:
            VCamError.notReady(data: .errorCode("not_ready"))
        }
    }

    private static func components(_ vector: SIMD3<Float>) -> [Double] {
        [Double(vector.x), Double(vector.y), Double(vector.z)]
    }

    /// JSON-RPC reports a wrong shape as invalid params rather than as an application error.
    private static func vector(_ values: [Double], of name: String) throws -> SIMD3<Float> {
        guard values.count == 3, values.allSatisfy(\.isFinite) else {
            throw JSONRPCErrorObject(code: -32602, message: "Invalid parameter \"\(name)\": expected 3 numbers")
        }
        return SIMD3(Float(values[0]), Float(values[1]), Float(values[2]))
    }

    private static func unitWeight(_ value: Double, of name: String) throws -> Float {
        guard value.isFinite, (0...1).contains(value) else {
            throw JSONRPCErrorObject(code: -32602, message: "Invalid parameter \"\(name)\": expected a number from 0 to 1")
        }
        return Float(value)
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

extension Shortcut {
    init(_ shortcut: VCamShortcut) {
        self.init(id: shortcut.id, title: shortcut.title)
    }
}
