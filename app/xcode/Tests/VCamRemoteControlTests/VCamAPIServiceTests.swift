import Foundation
import Testing
@testable import VCamBridge
import VCamControl
import VCamData
import VCamEntity
@testable import VCamRemoteControl

// Serialized: the tests swap global hooks (UniBridge.methodCallback / SceneControl.provider)
// and suspend while awaiting responses, so parallel tests would interfere
@MainActor
@Suite(.serialized)
struct VCamAPIServiceTests {
    private static let library: MotionLibrary = {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "VCamRemoteControlTests")
            .appending(path: UUID().uuidString)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return MotionLibrary(store: ImportedMotionStore(
            manifestURL: directory.appending(path: "manifest.json"),
            filesDirectory: directory.appending(path: "files")
        ))
    }()

    private func recordedMethodCalls<Call>(
        _ decode: @escaping (UniBridgeMethodId, UnsafeMutableRawPointer?) -> Call?,
        during body: () async throws -> Void
    ) async rethrows -> [Call] {
        nonisolated(unsafe) var calls: [Call] = []
        let originalCallback = UniBridge.methodCallback
        defer {
            UniBridge.methodCallback = originalCallback
        }
        UniBridge.methodCallback = { method, payload, _ in
            if let call = decode(method, payload) {
                calls.append(call)
            }
        }
        try await body()
        return calls
    }

    private func withSceneProvider<T>(_ provider: MockSceneProvider?, _ body: () async throws -> T) async rethrows -> T {
        let originalProvider = SceneControl.provider
        defer {
            SceneControl.provider = originalProvider
        }
        SceneControl.provider = provider
        return try await body()
    }

    private func withObjectProvider<T>(_ provider: MockSceneObjectProvider?, _ body: () async throws -> T) async rethrows -> T {
        let originalProvider = SceneObjectControl.provider
        defer {
            SceneObjectControl.provider = originalProvider
        }
        SceneObjectControl.provider = provider
        return try await body()
    }

    private func makeService(
        connectionID: UUID = UUID(),
        modelManager: ModelManager = ModelManager(models: []),
        uniState: UniState = UniState(),
        eventPublisher: EventPublisher = EventPublisher(),
        importManager: AvatarImportManager = .shared
    ) -> VCamAPIService {
        VCamAPIService(
            connectionID: connectionID,
            modelManager: modelManager,
            motionLibrary: Self.library,
            uniState: uniState,
            eventPublisher: eventPublisher,
            importManager: importManager
        )
    }

    private func call(_ service: VCamAPIService, method: String, params: String = "{}") async throws -> [String: JSONValue] {
        let body = Data(#"{"jsonrpc":"2.0","id":1,"method":"\#(method)","params":\#(params)}"#.utf8)
        let response = try #require(await VCamServer(handler: service).handle(body))
        return try JSONDecoder().decode([String: JSONValue].self, from: response)
    }

    private func errorObject(of response: [String: JSONValue]) -> (code: Int, dataCode: String)? {
        guard case .object(let error)? = response["error"],
              case .int(let code)? = error["code"],
              case .object(let data)? = error["data"],
              case .string(let dataCode)? = data["code"] else { return nil }
        return (code, dataCode)
    }

    @Test
    func appGetInfoReturnsAPIVersionFromBundledSpecification() async throws {
        let response = try await call(makeService(), method: "app.getInfo")
        guard case .object(let result)? = response["result"] else {
            Issue.record("Unexpected response: \(response)")
            return
        }
        #expect(result["apiVersion"] == .string(APISpecification.apiVersion))
        guard case .array(let capabilities)? = result["capabilities"] else {
            Issue.record("Unexpected capabilities: \(result)")
            return
        }
        #expect(capabilities.contains(.string("subtitle")))
    }

    @Test
    func rpcDiscoverServesBundledSpecification() async throws {
        let response = try await call(makeService(), method: "rpc.discover")
        guard case .object(let document)? = response["result"],
              case .object(let info)? = document["info"] else {
            Issue.record("Unexpected response: \(response)")
            return
        }
        #expect(info["version"] == .string(APISpecification.apiVersion))
    }

    @Test
    func motionPlayUsesAPITriggerLoopDefault() async throws {
        let motionID = MotionID.builtIn(name: "hi").rawValue
        var response: [String: JSONValue] = [:]
        let played = try await recordedMethodCalls({ method, payload -> (id: String, isLoop: Bool)? in
            guard method == .playMotion else { return nil }
            let payload = payload!.load(as: PlayMotionPayload.self)
            return (id: String(cString: payload.stringPtr!), isLoop: payload.isLoop == 1)
        }) {
            response = try await call(
                makeService(), method: "motion.play", params: #"{"motionId": "\#(motionID)"}"#)
        }

        #expect(response["result"] == .bool(true))
        #expect(played.count == 1)
        #expect(played.first?.id == motionID)
        #expect(played.first?.isLoop == false)
    }

    @Test
    func motionPlayReportsUnknownMotion() async throws {
        for motionID in ["invalid", "builtin:not-registered"] {
            let response = try await call(
                makeService(), method: "motion.play", params: #"{"motionId": "\#(motionID)"}"#)
            let error = errorObject(of: response)
            #expect(error?.code == 1002)
            #expect(error?.dataCode == "motion_not_found")
        }
    }

    @Test
    func motionStopReportsUnknownBuiltInMotion() async throws {
        let response = try await call(
            makeService(), method: "motion.stop", params: #"{"motionId": "builtin:not-registered"}"#)
        let error = errorObject(of: response)
        #expect(error?.code == 1002)
        #expect(error?.dataCode == "motion_not_found")
    }

    @Test
    func avatarLoadReportsUnknownAvatar() async throws {
        let response = try await call(
            makeService(), method: "avatar.load", params: #"{"avatarId": "\#(UUID().uuidString)"}"#)
        let error = errorObject(of: response)
        #expect(error?.code == 1001)
        #expect(error?.dataCode == "avatar_not_found")
    }

    @Test
    func avatarListReturnsRegisteredModels() async throws {
#if FEATURE_3
        let model = Models.Model(name: "internal-name", displayName: "Ada", type: .vrm)
#else
        let model = Models.Model(name: "internal-name", displayName: "Ada", type: .live2d)
#endif
        let service = makeService(modelManager: ModelManager(models: [model]))
        let response = try await call(service, method: "avatar.list")
        guard case .array(let avatars)? = response["result"],
              case .object(let avatar)? = avatars.first else {
            Issue.record("Unexpected response: \(response)")
            return
        }
        #expect(avatars.count == 1)
        #expect(avatar["id"] == .string(model.id.uuidString))
        #expect(avatar["name"] == .string("Ada"))
    }

    @Test
    func expressionSetValidatesAgainstCurrentExpressions() async throws {
        let uniState = UniState()
        uniState.expressions = [.init(name: "Joy")]
        let service = makeService(uniState: uniState)

        var success: [String: JSONValue] = [:]
        let applied = try await recordedMethodCalls({ method, payload in
            method == .applyExpression ? String(cString: payload!.assumingMemoryBound(to: CChar.self)) : nil
        }) {
            success = try await call(service, method: "expression.set", params: #"{"expressions": [{"name": "Joy", "weight": 1}]}"#)
        }
        #expect(success["result"] == .bool(true))
        #expect(applied == ["Joy"])

        let failure = try await call(service, method: "expression.set", params: #"{"expressions": [{"name": "Angry", "weight": 1}]}"#)
        #expect(errorObject(of: failure)?.code == 1003)
    }

    @Test
    func expressionSetKeepsTheExpressionWhenRepeated() async throws {
        let uniState = UniState()
        uniState.expressions = [.init(name: "Joy")]
        let service = makeService(uniState: uniState)

        let applied = try await recordedMethodCalls({ method, payload in
            method == .applyExpression ? String(cString: payload!.assumingMemoryBound(to: CChar.self)) : nil
        }) {
            _ = try await call(service, method: "expression.set", params: #"{"expressions": [{"name": "Joy", "weight": 1}]}"#)
            _ = try await call(service, method: "expression.set", params: #"{"expressions": [{"name": "Joy", "weight": 1}]}"#)
        }

        #expect(applied == ["Joy", "Joy"])
        #expect(uniState.currentExpressionName == "Joy")
    }

    @Test
    func expressionSetRejectsAWeightOutOfRange() async throws {
        let uniState = UniState()
        uniState.expressions = [.init(name: "Joy")]
        for weight in ["-0.1", "1.1"] {
            let failure = try await call(makeService(uniState: uniState), method: "expression.set", params: #"{"name": "Joy", "weight": \#(weight)}"#)
            guard case .object(let error)? = failure["error"] else {
                Issue.record("Unexpected response: \(failure)")
                continue
            }
            #expect(error["code"] == .int(-32602))
        }
    }

    @Test
    func expressionSetMixesAndReportsTheExpressions() async throws {
        let uniState = UniState()
        uniState.expressions = [.init(name: "笑顔"), .init(name: "Angry")]
        let service = makeService(uniState: uniState)

        let response = try await call(service, method: "expression.set", params: #"{"expressions": [{"name": "笑顔", "weight": 0.7}, {"name": "Angry", "weight": 0.3}]}"#)

        #expect(response["result"] == .bool(true))
        #expect(uniState.currentExpressions == [.init(name: "笑顔", weight: 0.7), .init(name: "Angry", weight: 0.3)])
        let state = try await call(service, method: "state.get")
        guard case .object(let result)? = state["result"] else {
            Issue.record("Unexpected response: \(state)")
            return
        }
        #expect(result["expressions"] == .array([
            .object(["name": .string("笑顔"), "weight": .number(0.7)]),
            .object(["name": .string("Angry"), "weight": .number(0.3)]),
        ]))
    }

    @Test
    func expressionSetPassesOnTheNameAsTheListSpellsIt() async throws {
        let uniState = UniState()
        let composed = "が"
        uniState.expressions = [.init(name: composed)]

        let decomposed = "\u{304B}\u{3099}"
        _ = try await call(makeService(uniState: uniState), method: "expression.set", params: #"{"expressions": [{"name": "\#(decomposed)", "weight": 0.5}]}"#)

        #expect(uniState.currentExpressions.first?.name.utf8.elementsEqual(composed.utf8) == true)
    }

    @Test
    func expressionSetChangesNothingWhenAnyExpressionIsWrong() async throws {
        let uniState = UniState()
        uniState.expressions = [.init(name: "Joy")]
        uniState.currentExpressionName = "Joy"
        let service = makeService(uniState: uniState)

        let unknown = try await call(service, method: "expression.set", params: #"{"expressions": [{"name": "Joy", "weight": 0.5}, {"name": "Angry", "weight": 0.5}]}"#)
        #expect(errorObject(of: unknown)?.dataCode == "expression_not_found")

        let repeated = try await call(service, method: "expression.set", params: #"{"expressions": [{"name": "Joy", "weight": 0.5}, {"name": "Joy", "weight": 0.5}]}"#)
        guard case .object(let error)? = repeated["error"] else {
            Issue.record("Unexpected response: \(repeated)")
            return
        }
        #expect(error["code"] == .int(-32602))
        #expect(uniState.currentExpressions == [.init(name: "Joy", weight: 1)])
    }

    @Test
    func gazeTakesItsTargetsAndRejectsAnglesOutOfRange() async throws {
        let calls = try await recordedMethodCalls({ method, payload in
            method == .setGaze ? payload?.load(as: GazePayload.self) : nil
        }) {
            _ = try await call(makeService(), method: "gaze.set", params: #"{"mode": "direction", "yaw": 30, "pitch": -5, "movesHead": false}"#)
            _ = try await call(makeService(), method: "gaze.set", params: #"{"mode": "camera"}"#)
            _ = try await call(makeService(), method: "gaze.set", params: #"{"mode": "auto"}"#)
            for params in [#"{"mode": "direction", "yaw": 120}"#, #"{"mode": "direction", "pitch": 60}"#] {
                let failure = try await call(makeService(), method: "gaze.set", params: params)
                guard case .object(let error)? = failure["error"] else {
                    Issue.record("Unexpected response: \(failure)")
                    continue
                }
                #expect(error["code"] == .int(-32602))
            }
        }

        #expect(calls.map(\.mode) == [GazeMode.direction, .camera, .auto].map(\.rawValue))
        #expect(calls[0].yaw == 30)
        #expect(calls[0].movesHead == 0)
        #expect(calls[1].movesHead == 1)
    }

    @Test
    func anEmptyListTakesTheExpressionsOff() async throws {
        let uniState = UniState()
        uniState.currentExpressionName = "Joy"
        let service = makeService(uniState: uniState)

        var response: [String: JSONValue] = [:]
        let applied = try await recordedMethodCalls({ method, payload in
            method == .applyExpression ? String(cString: payload!.assumingMemoryBound(to: CChar.self)) : nil
        }) {
            response = try await call(service, method: "expression.set", params: #"{"expressions": []}"#)
        }

        #expect(response["result"] == .bool(true))
        #expect(applied == [""])
        #expect(uniState.currentExpressionName == nil)
    }

    @Test
    func sceneGetReportsNotReadyWithoutProvider() async throws {
        try await withSceneProvider(nil) {
            let response = try await call(makeService(), method: "scene.get")
            let error = errorObject(of: response)
            #expect(error?.code == 1000)
            #expect(error?.dataCode == "not_ready")
        }
    }

    @Test
    func stateGetReportsTheSubtitle() async throws {
        let uniState = UniState()
        uniState.subtitle = "Hello"

        let response = try await call(makeService(uniState: uniState), method: "state.get")

        guard case .object(let result)? = response["result"] else {
            Issue.record("Unexpected response: \(response)")
            return
        }
        #expect(result["subtitle"] == .string("Hello"))
    }

    @Test
    func emojiShowPresentsOneEmojiAndListsTheCapability() async throws {
        var presentedCount = 0
        let originalHook = EmojiControl.presentStamp
        defer {
            EmojiControl.presentStamp = originalHook
        }
        EmojiControl.presentStamp = { _ in presentedCount += 1 }

        let info = try await call(makeService(), method: "app.getInfo")
        guard case .object(let result)? = info["result"], case .array(let capabilities)? = result["capabilities"] else {
            Issue.record("Unexpected response: \(info)")
            return
        }
        #expect(capabilities.contains(.string("emoji")))

        let shown = try await call(makeService(), method: "emoji.show", params: #"{"emoji": "🎉"}"#)
        #expect(shown["result"] == .bool(true))
        #expect(presentedCount == 1)

        for invalid in ["", "🎉🎉", "a"] {
            let failure = try await call(makeService(), method: "emoji.show", params: #"{"emoji": "\#(invalid)"}"#)
            guard case .object(let error)? = failure["error"] else {
                Issue.record("Unexpected response: \(failure)")
                continue
            }
            #expect(error["code"] == .int(-32602))
        }
        #expect(presentedCount == 1)
    }

    @Test
    func emojiShowIsUnsupportedWithoutAnOverlay() async throws {
        let originalHook = EmojiControl.presentStamp
        defer {
            EmojiControl.presentStamp = originalHook
        }
        EmojiControl.presentStamp = nil

        let response = try await call(makeService(), method: "emoji.show", params: #"{"emoji": "🎉"}"#)

        #expect(errorObject(of: response)?.dataCode == "unsupported_operation")
    }

    @Test
    func trackingGetStateReportsTheSources() async throws {
        let originalProvider = TrackingControl.provider
        defer {
            TrackingControl.provider = originalProvider
        }

        TrackingControl.provider = nil
        let notReady = try await call(makeService(), method: "tracking.getState")
        #expect(errorObject(of: notReady)?.dataCode == "not_ready")

        TrackingControl.provider = MockTrackingProvider()
        let response = try await call(makeService(), method: "tracking.getState")
        #expect(response["result"] == .object(["sources": .array([
            .object(["id": .string("vcamMotion"), "status": .string("connected")]),
            .object(["id": .string("vmcProtocol"), "status": .string("connecting")]),
            .object(["id": .string("iFacialMocap"), "status": .string("disconnected")]),
        ])]))
    }

    // MARK: - Scenes

    @Test
    func sceneOperationsReportTheirErrors() async throws {
        let provider = MockSceneProvider()
        try await withSceneProvider(provider) {
            let created = try await call(makeService(), method: "scene.create", params: #"{"name": "Talk"}"#)
            #expect(created["result"] == .object(["id": .int(3), "name": .string("Talk")]))

            let missing = try await call(makeService(), method: "scene.rename", params: #"{"sceneId": 99, "name": "x"}"#)
            #expect(errorObject(of: missing)?.dataCode == "scene_not_found")

            let renamed = try await call(makeService(), method: "scene.rename", params: #"{"sceneId": 2, "name": "Sub2"}"#)
            #expect(renamed["result"] == .bool(true))
            #expect(provider.renamed.first?.name == "Sub2")

            let last = try await call(makeService(), method: "scene.remove", params: #"{"sceneId": 1}"#)
            #expect(errorObject(of: last)?.dataCode == "scene_not_removable")
        }
    }

    @Test
    func sceneLightingFollowsTheRenderingFeature() async throws {
        let originalFeatures = RenderingFeature.supported
        defer {
            RenderingFeature.supported = originalFeatures
        }
        let provider = MockSceneProvider()
        try await withSceneProvider(provider) {
            RenderingFeature.supported.remove(.sceneLighting)
            let unsupported = try await call(makeService(), method: "scene.getLighting")
            #expect(errorObject(of: unsupported)?.dataCode == "unsupported_operation")

            RenderingFeature.supported.insert(.sceneLighting)
            let params = ##"{"lighting": {"azimuth": 30, "elevation": 45, "shadow": 0.5, "shadowColor": "#102030"}}"##
            let set = try await call(makeService(), method: "scene.setLighting", params: params)
            #expect(set["result"] == .bool(true))
            #expect(provider.lighting?.azimuth == 30)
            #expect(provider.lighting?.rim == nil)

            let invalid = ##"{"lighting": {"azimuth": 0, "elevation": 0, "shadow": 2, "shadowColor": "#000000"}}"##
            let failure = try await call(makeService(), method: "scene.setLighting", params: invalid)
            #expect(failure["error"] != nil)
        }
    }

    @Test
    func theEngineDoesNotOfferTheAPI() {
        #expect(!RenderingFeature.engine.contains(.externalControl))
    }

    // MARK: - Frame capture

    @Test
    func frameCaptureNeedsTheUsersPermission() async throws {
        let original = UserDefaults.standard.value(for: .integrationExternalControlFrameCapture)
        defer {
            UserDefaults.standard.set(original, for: .integrationExternalControlFrameCapture)
        }
        UserDefaults.standard.set(false, for: .integrationExternalControlFrameCapture)

        let response = try await call(makeService(), method: "frame.capture")

        #expect(errorObject(of: response)?.dataCode == "frame_capture_disabled")
    }

    // MARK: - Objects

    @Test
    func objectListReportsPlacementsAsFractions() async throws {
        try await withObjectProvider(MockSceneObjectProvider()) {
            let response = try await call(makeService(), method: "object.list")
            #expect(response["result"] == .array([
                .object(["id": .int(Int(SceneObject.avatarID)), "type": .string("avatar"), "name": .string(""), "isHidden": .bool(false), "isLocked": .bool(false)]),
                .object([
                    "id": .int(1), "type": .string("text"), "name": .string("Title"), "isHidden": .bool(true), "isLocked": .bool(false),
                    "placement": .object(["x": .number(0.1), "y": .number(-0.2), "width": .number(0.5), "height": .number(0.25)]),
                ]),
            ]))
        }
    }

    @Test
    func objectUpdatePassesChangesAndMapsErrors() async throws {
        let provider = MockSceneObjectProvider()
        try await withObjectProvider(provider) {
            let success = try await call(makeService(), method: "object.update", params: #"{"objectId": 1, "isHidden": false, "placement": {"x": 0.25}}"#)
            #expect(success["result"] == .bool(true))
            #expect(provider.changes.first?.change.isHidden == false)
            #expect(provider.changes.first?.change.placement?.x == 0.25)
            #expect(provider.changes.first?.change.placement?.width == nil)

            let missing = try await call(makeService(), method: "object.update", params: #"{"objectId": 99, "isHidden": true}"#)
            #expect(errorObject(of: missing)?.dataCode == "object_not_found")

            let locked = try await call(makeService(), method: "object.update", params: #"{"objectId": 98, "isHidden": true}"#)
            #expect(errorObject(of: locked)?.dataCode == "object_locked")

            let invalid = try await call(makeService(), method: "object.update", params: #"{"objectId": 1, "placement": {"width": -1}}"#)
            guard case .object(let error)? = invalid["error"] else {
                Issue.record("Unexpected response: \(invalid)")
                return
            }
            #expect(error["code"] == .int(-32602))
        }
    }

    @Test
    func aDurationAnimatesThePlacementAndLeavesTheRestImmediate() async throws {
        let provider = MockSceneObjectProvider()
        try await withObjectProvider(provider) {
            let params = #"{"objectId": 1, "name": "Moved", "isLocked": true, "placement": {"x": 0.25}, "duration": 1.5, "easing": "easeOut"}"#
            let response = try await call(makeService(), method: "object.update", params: params)

            #expect(response["result"] == .bool(true))
            let animation = try #require(provider.animations.first)
            #expect(animation.placement.x == 0.25)
            #expect(animation.animation.duration == 1.5)
            #expect(animation.animation.easing == .easeOut)
            #expect(provider.changes.first?.change.name == "Moved")
            #expect(provider.changes.first?.change.placement == nil)
            // The lock comes after the move, since a locked object rejects it
            #expect(provider.changes.last?.change.isLocked == true)
        }
    }

    @Test
    func aDurationFadesTheVisibility() async throws {
        let provider = MockSceneObjectProvider()
        try await withObjectProvider(provider) {
            _ = try await call(makeService(), method: "object.update", params: #"{"objectId": 1, "isHidden": true, "placement": {"x": 0}, "duration": 0.5}"#)

            #expect(provider.fades.first?.isHidden == true)
            #expect(provider.fades.first?.animation.duration == 0.5)
            #expect(provider.animations.count == 1)
            #expect(provider.changes.isEmpty)
        }
    }

    @Test
    func withoutADurationTheVisibilityIsImmediate() async throws {
        let provider = MockSceneObjectProvider()
        try await withObjectProvider(provider) {
            _ = try await call(makeService(), method: "object.update", params: #"{"objectId": 1, "isHidden": true}"#)

            #expect(provider.fades.isEmpty)
            #expect(provider.changes.first?.change.isHidden == true)
        }
    }

    @Test
    func subtitlePlacementAnimatesWithADuration() async throws {
        let provider = MockSceneObjectProvider()
        try await withObjectProvider(provider) {
            _ = try await call(makeService(), method: "subtitle.setStyle", params: #"{"placement": {"bottomY": -0.2}, "duration": 1}"#)

            #expect(provider.animatedSubtitleStyles.first?.style.bottomY == -0.2)
            #expect(provider.subtitleStyle.bottomY == -0.47)
        }
    }

    @Test
    func subtitleStyleAloneDoesNotAnimate() async throws {
        let provider = MockSceneObjectProvider()
        try await withObjectProvider(provider) {
            _ = try await call(makeService(), method: "subtitle.setStyle", params: #"{"style": {"fontSize": 64}, "duration": 1}"#)

            #expect(provider.animatedSubtitleStyles.isEmpty)
            #expect(provider.subtitleStyle.configuration.fontSize == 64)
        }
    }

    @Test
    func zoomOutOfRangeIsRejected() async throws {
        for zoom in ["0", "-1", "11"] {
            let failure = try await call(makeService(), method: "camera.adjust", params: #"{"zoom": \#(zoom)}"#)
            guard case .object(let error)? = failure["error"] else {
                Issue.record("Unexpected response: \(failure)")
                continue
            }
            #expect(error["code"] == .int(-32602))
        }
    }

    @Test
    func sceneLoadRejectsADurationOutOfRange() async throws {
        try await withSceneProvider(MockSceneProvider()) {
            let failure = try await call(makeService(), method: "scene.load", params: #"{"sceneId": 2, "duration": 100}"#)
            guard case .object(let error)? = failure["error"] else {
                Issue.record("Unexpected response: \(failure)")
                return
            }
            #expect(error["code"] == .int(-32602))
        }
    }

    @Test
    func withoutADurationThePlacementIsImmediate() async throws {
        let provider = MockSceneObjectProvider()
        try await withObjectProvider(provider) {
            for params in [#"{"objectId": 1, "placement": {"x": 0.25}}"#, #"{"objectId": 1, "placement": {"x": 0.25}, "duration": 0}"#] {
                _ = try await call(makeService(), method: "object.update", params: params)
            }

            #expect(provider.animations.isEmpty)
            #expect(provider.changes.map(\.change.placement?.x) == [0.25, 0.25])
        }
    }

    @Test
    func animationsDefaultToEaseInOut() async throws {
        let provider = MockSceneObjectProvider()
        try await withObjectProvider(provider) {
            _ = try await call(makeService(), method: "object.update", params: #"{"objectId": 1, "placement": {"x": 0}, "duration": 1}"#)

            #expect(provider.animations.first?.animation.easing == .easeInOut)
        }
    }

    @Test
    func lockedObjectsRejectAnimations() async throws {
        try await withObjectProvider(MockSceneObjectProvider()) {
            let response = try await call(makeService(), method: "object.update", params: #"{"objectId": 98, "placement": {"x": 0}, "duration": 1}"#)

            #expect(errorObject(of: response)?.dataCode == "object_locked")
        }
    }

    @Test
    func durationsOutOfRangeAreRejected() async throws {
        try await withObjectProvider(MockSceneObjectProvider()) {
            for duration in ["-1", "61"] {
                for (method, params) in [("camera.adjust", #"{"zoom": 1, "duration": \#(duration)}"#), ("object.update", #"{"objectId": 1, "placement": {"x": 0}, "duration": \#(duration)}"#)] {
                    let failure = try await call(makeService(), method: method, params: params)
                    guard case .object(let error)? = failure["error"] else {
                        Issue.record("Unexpected response: \(failure)")
                        continue
                    }
                    #expect(error["code"] == .int(-32602))
                }
            }
        }
    }

    @Test
    func objectsTheAppKeepsAreNotDuplicatedOrRemoved() async throws {
        try await withObjectProvider(MockSceneObjectProvider()) {
            let avatarID = Int(SceneObject.avatarID)
            let duplicate = try await call(makeService(), method: "object.duplicate", params: #"{"objectId": \#(avatarID)}"#)
            #expect(errorObject(of: duplicate)?.dataCode == "object_not_duplicable")

            let remove = try await call(makeService(), method: "object.remove", params: #"{"objectId": \#(avatarID)}"#)
            #expect(errorObject(of: remove)?.dataCode == "object_not_removable")
        }
    }

    @Test
    func objectMethodsReportNotReadyWithoutProvider() async throws {
        try await withObjectProvider(nil) {
            let response = try await call(makeService(), method: "object.list")
            #expect(errorObject(of: response)?.dataCode == "not_ready")
        }
    }

    // MARK: - Text

    @Test
    func textAddLayersStyleOverPresetOverDefault() async throws {
        let provider = MockSceneObjectProvider()
        try await withObjectProvider(provider) {
            let response = try await call(makeService(), method: "text.add", params: ##"{"text": "Hi", "preset": "bold", "style": {"color": "#FF0000"}, "name": "Greeting", "placement": {"x": 0.1}}"##)
            #expect(response["result"] == .object(["objectId": .int(5)]))

            let added = try #require(provider.addedTexts.first)
            #expect(added.text == "Hi")
            #expect(added.fontName == "Preset")
            #expect(added.fontSize == 100)
            #expect(added.fill == .solid(.init(red: 1, green: 0, blue: 0)))
            #expect(provider.changes.first?.id == 5)
            #expect(provider.changes.first?.change.name == "Greeting")
            #expect(provider.changes.first?.change.placement?.x == 0.1)
        }
    }

    @Test
    func textAddRejectsUnknownFontsAndPresets() async throws {
        let provider = MockSceneObjectProvider()
        try await withObjectProvider(provider) {
            for params in [#"{"text": "Hi", "style": {"fontName": "Missing"}}"#, #"{"text": "Hi", "preset": "missing"}"#] {
                let failure = try await call(makeService(), method: "text.add", params: params)
                guard case .object(let error)? = failure["error"] else {
                    Issue.record("Unexpected response: \(failure)")
                    continue
                }
                #expect(error["code"] == .int(-32602))
            }
            #expect(provider.addedTexts.isEmpty)
        }
    }

    @Test
    func textUpdateKeepsWhatIsNotMentioned() async throws {
        let provider = MockSceneObjectProvider()
        try await withObjectProvider(provider) {
            _ = try await call(makeService(), method: "text.update", params: #"{"objectId": 1, "style": {"fontName": "Chosen"}}"#)

            let updated = try #require(provider.updatedTexts.first)
            #expect(updated.text == "Hello")
            #expect(updated.fontName == "Chosen")
            #expect(updated.fontSize == 100)
        }
    }

    @Test
    func textMethodsRejectOtherObjects() async throws {
        try await withObjectProvider(MockSceneObjectProvider()) {
            let response = try await call(makeService(), method: "text.get", params: #"{"objectId": \#(Int(SceneObject.avatarID))}"#)
            #expect(errorObject(of: response)?.dataCode == "object_type_mismatch")
        }
    }

    @Test
    func subtitleStyleKeepsWhatIsNotMentioned() async throws {
        let provider = MockSceneObjectProvider()
        try await withObjectProvider(provider) {
            _ = try await call(makeService(), method: "subtitle.setStyle", params: #"{"style": {"fontSize": 64}, "placement": {"bottomY": -0.3}}"#)

            #expect(provider.subtitleStyle.configuration.fontName == "Base")
            #expect(provider.subtitleStyle.configuration.fontSize == 64)
            #expect(provider.subtitleStyle.bottomY == -0.3)
            #expect(provider.subtitleStyle.size == 1)
        }
    }

    // MARK: - Motions

    private func completingRegistrations<Result>(errorCode: Int32, during body: () async throws -> Result) async rethrows -> Result {
        let originalCallback = UniBridge.methodCallback
        defer {
            UniBridge.methodCallback = originalCallback
        }
        UniBridge.methodCallback = { method, payload, _ in
            guard method == .registerImportedMotion else { return }
            MainActor.assumeIsolated {
                UniBridge.completeRequest(method: method, payload: payload, errorCode: errorCode)
            }
        }
        return try await body()
    }

    private func beginMotionUpload(_ service: VCamAPIService, importManager: AvatarImportManager, connectionID: UUID) async throws -> String {
        let begin = try await call(service, method: "motion.import.begin", params: #"{"filename": "clip.vrma"}"#)
        guard case .object(let result)? = begin["result"], case .string(let importId)? = result["importId"] else {
            Issue.record("Unexpected response: \(begin)")
            return ""
        }
        importManager.staging.receiveFrame(Data(importId.utf8) + Data("vrma".utf8), connectionID: connectionID)
        return importId
    }

    @Test
    func anImportedMotionJoinsTheListAndCanBeRemoved() async throws {
        let importManager = makeImportManager()
        let connectionID = UUID()
        let service = makeService(connectionID: connectionID, importManager: importManager)
        let originalProvider = MotionControl.durationProvider
        defer {
            MotionControl.durationProvider = originalProvider
        }
        MotionControl.durationProvider = { _ in 2.5 }

        let importId = try await beginMotionUpload(service, importManager: importManager, connectionID: connectionID)
        let response = try await completingRegistrations(errorCode: 0) {
            try await call(service, method: "motion.import.commit", params: #"{"importId": "\#(importId)", "name": "Wave"}"#)
        }

        guard case .object(let result)? = response["result"], case .string(let motionId)? = result["motionId"] else {
            Issue.record("Unexpected response: \(response)")
            return
        }
        #expect(result["duration"] == .number(2.5))

        let list = try await call(service, method: "motion.list")
        guard case .array(let motions)? = list["result"] else {
            Issue.record("Unexpected response: \(list)")
            return
        }
        #expect(motions.contains { motion in
            guard case .object(let fields) = motion else { return false }
            return fields["id"] == .string(motionId) && fields["name"] == .string("Wave") && fields["duration"] == .number(2.5)
        })

        let removed = try await call(service, method: "motion.remove", params: #"{"motionId": "\#(motionId)"}"#)
        #expect(removed["result"] == .bool(true))
        let again = try await call(service, method: "motion.remove", params: #"{"motionId": "\#(motionId)"}"#)
        #expect(errorObject(of: again)?.dataCode == "motion_not_found")
    }

    @Test
    func aMotionTheRendererRejectsIsInvalid() async throws {
        let importManager = makeImportManager()
        let connectionID = UUID()
        let service = makeService(connectionID: connectionID, importManager: importManager)
        let importId = try await beginMotionUpload(service, importManager: importManager, connectionID: connectionID)

        let response = try await completingRegistrations(errorCode: VrmaMotionError.unknown.rawValue) {
            try await call(service, method: "motion.import.commit", params: #"{"importId": "\#(importId)"}"#)
        }

        #expect(errorObject(of: response)?.dataCode == "invalid_motion")
    }

    @Test
    func motionImportRefusesOtherFileTypes() async throws {
        let service = makeService(importManager: makeImportManager())

        let response = try await call(service, method: "motion.import.begin", params: #"{"filename": "script.sh"}"#)

        #expect(errorObject(of: response)?.dataCode == "import_failed")
    }

    @Test
    func builtInMotionsCannotBeRemoved() async throws {
        let response = try await call(makeService(), method: "motion.remove", params: #"{"motionId": "builtin:hi"}"#)

        #expect(errorObject(of: response)?.dataCode == "unsupported_operation")
    }

    @Test
    func waitingForAMotionRespondsWhenItStops() async throws {
        let uniState = UniState()
        let service = makeService(uniState: uniState)
        let playing = Task { @MainActor in
            try await call(service, method: "motion.play", params: #"{"motionId": "builtin:hi", "wait": true, "loop": false}"#)
        }
        try await Task.sleep(for: .milliseconds(60))
        uniState.isMotionPlaying = ["builtin:hi": true]
        try await Task.sleep(for: .milliseconds(60))
        uniState.isMotionPlaying = ["builtin:hi": false]

        let response = try await playing.value

        #expect(response["result"] == .bool(true))
    }

    @Test
    func waitingForALoopRespondsAtOnce() async throws {
        let start = ContinuousClock.now

        let response = try await call(makeService(), method: "motion.play", params: #"{"motionId": "builtin:hi", "wait": true, "loop": true}"#)

        #expect(response["result"] == .bool(true))
        #expect(ContinuousClock.now - start < .seconds(1))
    }

    // MARK: - Images

    private func makeImportManager() -> AvatarImportManager {
        AvatarImportManager(staging: UploadStaging(
            stagingDirectory: FileManager.default.temporaryDirectory
                .appending(path: "VCamAPIServiceTests")
                .appending(path: UUID().uuidString)
        ))
    }

    @Test
    func imageImportHandsTheUploadedFileToTheProvider() async throws {
        let provider = MockSceneObjectProvider()
        let importManager = makeImportManager()
        let connectionID = UUID()
        let service = makeService(connectionID: connectionID, importManager: importManager)
        try await withObjectProvider(provider) {
            let begin = try await call(service, method: "image.import.begin", params: #"{"filename": "photo.PNG"}"#)
            guard case .object(let result)? = begin["result"], case .string(let importId)? = result["importId"] else {
                Issue.record("Unexpected response: \(begin)")
                return
            }
            importManager.staging.receiveFrame(Data(importId.utf8) + Data("image".utf8), connectionID: connectionID)

            let commit = try await call(service, method: "image.import.commit", params: #"{"importId": "\#(importId)"}"#)

            #expect(commit["result"] == .object(["objectId": .int(6)]))
            #expect(provider.addedImageWasReadable == true)
            #expect(importManager.staging.stagedFileURL(importId: try #require(UUID(uuidString: importId))) == nil)
        }
    }

    @Test
    func imageImportRefusesOtherFileTypes() async throws {
        try await withObjectProvider(MockSceneObjectProvider()) {
            let service = makeService(importManager: makeImportManager())
            let response = try await call(service, method: "image.import.begin", params: #"{"filename": "script.sh"}"#)
            #expect(errorObject(of: response)?.dataCode == "import_failed")
        }
    }

    // MARK: - Videos

    private func beginVideoUpload(_ service: VCamAPIService, importManager: AvatarImportManager, connectionID: UUID) async throws -> String {
        let begin = try await call(service, method: "video.import.begin", params: #"{"filename": "clip.mp4"}"#)
        guard case .object(let result)? = begin["result"], case .string(let importId)? = result["importId"] else {
            Issue.record("Unexpected response: \(begin)")
            return ""
        }
        importManager.staging.receiveFrame(Data(importId.utf8) + Data("video".utf8), connectionID: connectionID)
        return importId
    }

    @Test
    func videoImportUsesTheDefaultsAndReportsTheLength() async throws {
        let provider = MockSceneObjectProvider()
        let importManager = makeImportManager()
        let connectionID = UUID()
        let service = makeService(connectionID: connectionID, importManager: importManager)
        try await withObjectProvider(provider) {
            let importId = try await beginVideoUpload(service, importManager: importManager, connectionID: connectionID)

            let commit = try await call(service, method: "video.import.commit", params: #"{"importId": "\#(importId)"}"#)

            #expect(commit["result"] == .object(["objectId": .int(8), "duration": .number(2.5)]))
            #expect(provider.addedVideos.first?.isLooping == true)
            #expect(provider.addedVideos.first?.isMuted == true)
            #expect(provider.addedVideos.first?.fileExtension == "mp4")
            #expect(importManager.staging.stagedFileURL(importId: try #require(UUID(uuidString: importId))) == nil)
        }
    }

    @Test
    func videoImportPassesItsOptions() async throws {
        let provider = MockSceneObjectProvider()
        let importManager = makeImportManager()
        let connectionID = UUID()
        let service = makeService(connectionID: connectionID, importManager: importManager)
        try await withObjectProvider(provider) {
            let importId = try await beginVideoUpload(service, importManager: importManager, connectionID: connectionID)

            _ = try await call(service, method: "video.import.commit", params: #"{"importId": "\#(importId)", "name": "Clip", "isLooping": false, "isMuted": false}"#)

            #expect(provider.addedVideos.first?.isLooping == false)
            #expect(provider.addedVideos.first?.isMuted == false)
            #expect(provider.changes.first?.change.name == "Clip")
        }
    }

    @Test
    func videoImportRefusesOtherFileTypes() async throws {
        try await withObjectProvider(MockSceneObjectProvider()) {
            let service = makeService(importManager: makeImportManager())
            let response = try await call(service, method: "video.import.begin", params: #"{"filename": "script.sh"}"#)
            #expect(errorObject(of: response)?.dataCode == "import_failed")
        }
    }

    @Test
    func videoImportRefusesWhatCannotBePlayed() async throws {
        let provider = MockSceneObjectProvider()
        provider.acceptsVideos = false
        let importManager = makeImportManager()
        let connectionID = UUID()
        let service = makeService(connectionID: connectionID, importManager: importManager)
        try await withObjectProvider(provider) {
            let importId = try await beginVideoUpload(service, importManager: importManager, connectionID: connectionID)

            let response = try await call(service, method: "video.import.commit", params: #"{"importId": "\#(importId)"}"#)

            #expect(errorObject(of: response)?.dataCode == "invalid_video")
        }
    }

    @Test
    func videoUpdatePassesOnlyWhatWasGivenAndReturnsTheState() async throws {
        let provider = MockSceneObjectProvider()
        try await withObjectProvider(provider) {
            let response = try await call(makeService(), method: "video.update", params: #"{"objectId": 8, "isPlaying": false, "time": 1.5}"#)

            #expect(provider.videoChanges.first?.id == 8)
            #expect(provider.videoChanges.first?.change == .init(isPlaying: false, time: 1.5))
            guard case .object(let state)? = response["result"] else {
                Issue.record("Unexpected response: \(response)")
                return
            }
            #expect(state["duration"] == .number(2.5))
        }
    }

    @Test
    func videoUpdateRefusesAnImpossibleTime() async throws {
        let provider = MockSceneObjectProvider()
        try await withObjectProvider(provider) {
            let response = try await call(makeService(), method: "video.update", params: #"{"objectId": 8, "time": -1}"#)

            guard case .object(let error)? = response["error"] else {
                Issue.record("Unexpected response: \(response)")
                return
            }
            #expect(error["code"] == .int(-32602))
            #expect(provider.videoChanges.isEmpty)
        }
    }

    @Test
    func videoGetRefusesOtherObjects() async throws {
        let provider = MockSceneObjectProvider()
        provider.videoError = .typeMismatch
        try await withObjectProvider(provider) {
            let response = try await call(makeService(), method: "video.get", params: #"{"objectId": 1}"#)
            #expect(errorObject(of: response)?.dataCode == "object_type_mismatch")
        }
    }

    // MARK: - Web

    @Test
    func webAddUsesTheDefaultsAndOnlyTakesWebURLs() async throws {
        let provider = MockSceneObjectProvider()
        try await withObjectProvider(provider) {
            let added = try await call(makeService(), method: "web.add", params: #"{"url": "https://example.com/chat"}"#)
            #expect(added["result"] == .object(["objectId": .int(7)]))
            #expect(provider.addedWebs.first?.size == CGSize(width: 800, height: 600))
            #expect(provider.addedWebs.first?.fps == 6)

            for params in [#"{"url": "file:///etc/hosts"}"#, #"{"url": "https://example.com", "fps": 0}"#, #"{"url": "https://example.com", "width": 0}"#] {
                let failure = try await call(makeService(), method: "web.add", params: params)
                guard case .object(let error)? = failure["error"] else {
                    Issue.record("Unexpected response: \(failure)")
                    continue
                }
                #expect(error["code"] == .int(-32602))
            }
            #expect(provider.addedWebs.count == 1)
        }
    }

    @Test
    func sceneListReportsNotReadyWithoutProvider() async throws {
        try await withSceneProvider(nil) {
            let response = try await call(makeService(), method: "scene.list")
            let error = errorObject(of: response)
            #expect(error?.code == 1000)
            #expect(error?.dataCode == "not_ready")
        }
    }

    @Test
    func sceneListReturnsTheScenesLoadAccepts() async throws {
        try await withSceneProvider(MockSceneProvider()) {
            let response = try await call(makeService(), method: "scene.list")
            #expect(response["result"] == .array([
                .object(["id": .int(1), "name": .string("Main")]),
                .object(["id": .int(2), "name": .string("Sub")]),
            ]))
        }
    }

    @Test
    func sceneLoadDelegatesToProvider() async throws {
        let provider = MockSceneProvider()
        try await withSceneProvider(provider) {
            let success = try await call(makeService(), method: "scene.load", params: #"{"sceneId": 2}"#)
            #expect(success["result"] == .bool(true))
            #expect(provider.loadedSceneIds == [2])

            let failure = try await call(makeService(), method: "scene.load", params: #"{"sceneId": 99}"#)
            #expect(errorObject(of: failure)?.code == 1004)
            #expect(provider.loadedSceneIds == [2])
        }
    }

    @Test
    func subtitleSetAndClearDriveTheSharedState() async throws {
        let uniState = UniState()
        let service = makeService(uniState: uniState)

        let set = try await call(service, method: "subtitle.set", params: #"{"text": "Hello"}"#)
        #expect(set["result"] == .bool(true))
        #expect(uniState.subtitle == "Hello")

        let cleared = try await call(service, method: "subtitle.clear")
        #expect(cleared["result"] == .bool(true))
        #expect(uniState.subtitle.isEmpty)
    }

    // MARK: - Pose

    private func withPoseEditor<T>(_ editor: MockPoseEditor?, _ body: () async throws -> T) async rethrows -> T {
        let originalProvider = PoseControl.provider
        defer {
            PoseControl.provider = originalProvider
        }
        PoseControl.provider = editor
        return try await body()
    }

    @Test
    func poseMethodsAreUnsupportedWithoutAnEditor() async throws {
        try await withPoseEditor(nil) {
            let response = try await call(makeService(), method: "pose.open")
            let error = errorObject(of: response)
            #expect(error?.code == 1008)
            #expect(error?.dataCode == "unsupported_operation")

            let info = try await call(makeService(), method: "app.getInfo")
            guard case .object(let result)? = info["result"], case .array(let capabilities)? = result["capabilities"] else {
                Issue.record("Unexpected response: \(info)")
                return
            }
            #expect(!capabilities.contains(.string("poseEditor")))
        }
    }

    @Test
    func poseOpenLoadsTheEditorAndListsBones() async throws {
        let editor = MockPoseEditor()
        try await withPoseEditor(editor) {
            let info = try await call(makeService(), method: "app.getInfo")
            guard case .object(let result)? = info["result"], case .array(let capabilities)? = result["capabilities"] else {
                Issue.record("Unexpected response: \(info)")
                return
            }
            #expect(capabilities.contains(.string("poseEditor")))

            let response = try await call(makeService(), method: "pose.open")
            #expect(response["result"] == .object([
                "bones": .array([.string("hips"), .string("leftUpperArm"), .string("leftHand")]),
                "movableBones": .array([.string("hips"), .string("leftHand")]),
                "expressions": .array([.string("happy"), .string("Wink")]),
            ]))
            #expect(editor.isOpen)
        }
    }

    @Test
    func poseMethodsRequireAnOpenEditor() async throws {
        let editor = MockPoseEditor()
        try await withPoseEditor(editor) {
            for method in ["pose.get", "pose.reset", "pose.expressions.get", "pose.expressions.reset", "pose.apply", "pose.export"] {
                let response = try await call(makeService(), method: method)
                let error = errorObject(of: response)
                #expect(error?.code == 1009, "\(method)")
                #expect(error?.dataCode == "pose_editor_not_open", "\(method)")
            }
            let response = try await call(makeService(), method: "pose.set", params: #"{"joints": []}"#)
            #expect(errorObject(of: response)?.code == 1009)
        }
    }

    @Test
    func poseSetAndGetRoundTripThroughTheEditor() async throws {
        let editor = MockPoseEditor()
        editor.isOpen = true
        try await withPoseEditor(editor) {
            let set = try await call(
                makeService(), method: "pose.set",
                params: #"{"joints": [{"name": "leftUpperArm", "rotation": [0, 0, -60]}, {"name": "hips", "rotation": [0, 10, 0], "position": [0, 0.5, 0]}]}"#)
            #expect(set["result"] == .bool(true))
            #expect(editor.pose["leftUpperArm"]?.rotation == SIMD3(0, 0, -60))
            #expect(editor.pose["hips"]?.position == SIMD3(0, 0.5, 0))

            let get = try await call(makeService(), method: "pose.get")
            guard case .array(let joints)? = get["result"] else {
                Issue.record("Unexpected response: \(get)")
                return
            }
            #expect(joints.count == 2)
            // Whole numbers decode as ints, so compare through the typed model
            let decoded = try JSONDecoder().decode([JointPose].self, from: JSONEncoder().encode(joints))
            #expect(decoded.contains(JointPose(name: "leftUpperArm", rotation: [0, 0, -60])))
            // Values pass through Float, so use numbers that Double represents exactly
            #expect(decoded.contains(JointPose(effector: [0, 1, 0], name: "hips", position: [0, 0.5, 0], rotation: [0, 10, 0])))

            let unknown = try await call(
                makeService(), method: "pose.set", params: #"{"joints": [{"name": "tail", "rotation": [0, 0, 0]}]}"#)
            let error = errorObject(of: unknown)
            #expect(error?.code == 1010)
            #expect(error?.dataCode == "bone_not_found")

            let malformed = try await call(
                makeService(), method: "pose.set", params: #"{"joints": [{"name": "hips", "rotation": [0, 0]}]}"#)
            guard case .object(let malformedError)? = malformed["error"], case .int(let code)? = malformedError["code"] else {
                Issue.record("Unexpected response: \(malformed)")
                return
            }
            #expect(code == -32602)
        }
    }

    @Test
    func poseMoveSolvesThroughTheEditorAndReturnsThePose() async throws {
        let editor = MockPoseEditor()
        try await withPoseEditor(editor) {
            let open = try await call(makeService(), method: "pose.open")
            guard case .object(let rig)? = open["result"] else {
                Issue.record("Unexpected response: \(open)")
                return
            }
            #expect(rig["movableBones"] == .array([.string("hips"), .string("leftHand")]))

            let moved = try await call(
                makeService(), method: "pose.move",
                params: #"{"joints": [{"name": "leftHand", "position": [0.25, 1.5, 0.125]}], "plantFeet": false}"#)
            #expect(editor.effectors["leftHand"] == SIMD3(0.25, 1.5, 0.125))
            #expect(editor.movedWithPlantedFeet == false)
            guard case .array(let joints)? = moved["result"] else {
                Issue.record("Unexpected response: \(moved)")
                return
            }
            let decoded = try JSONDecoder().decode([JointPose].self, from: JSONEncoder().encode(joints))
            #expect(decoded.contains(JointPose(effector: [0.25, 1.5, 0.125], name: "leftHand", rotation: [0, 0, 45])))

            _ = try await call(makeService(), method: "pose.move", params: #"{"joints": [{"name": "hips", "position": [0, 0.75, 0]}]}"#)
            #expect(editor.movedWithPlantedFeet == true)

            let notMovable = try await call(
                makeService(), method: "pose.move", params: #"{"joints": [{"name": "leftUpperArm", "position": [0, 1, 0]}]}"#)
            #expect(errorObject(of: notMovable)?.dataCode == "bone_not_movable")
            #expect(errorObject(of: notMovable)?.code == 1011)
            let unknown = try await call(
                makeService(), method: "pose.move", params: #"{"joints": [{"name": "tail", "position": [0, 1, 0]}]}"#)
            #expect(errorObject(of: unknown)?.dataCode == "bone_not_found")
            let malformed = try await call(
                makeService(), method: "pose.move", params: #"{"joints": [{"name": "leftHand", "position": [0, 1]}]}"#)
            guard case .object(let malformedError)? = malformed["error"], case .int(let code)? = malformedError["code"] else {
                Issue.record("Unexpected response: \(malformed)")
                return
            }
            #expect(code == -32602)
        }
    }

    @Test
    func poseExpressionsRoundTripThroughTheEditor() async throws {
        let editor = MockPoseEditor()
        editor.isOpen = true
        try await withPoseEditor(editor) {
            let set = try await call(
                makeService(), method: "pose.expressions.set",
                params: #"{"expressions": [{"name": "happy", "weight": 0.5}, {"name": "Wink", "weight": 1}]}"#)
            #expect(set["result"] == .bool(true))
            #expect(editor.expressions == ["happy": 0.5, "Wink": 1])

            let get = try await call(makeService(), method: "pose.expressions.get")
            guard case .array(let weights)? = get["result"] else {
                Issue.record("Unexpected response: \(get)")
                return
            }
            let decoded = try JSONDecoder().decode([ExpressionWeight].self, from: JSONEncoder().encode(weights))
            #expect(decoded == [ExpressionWeight(name: "happy", weight: 0.5), ExpressionWeight(name: "Wink", weight: 1)])

            let reset = try await call(makeService(), method: "pose.expressions.reset", params: #"{"names": ["happy"]}"#)
            #expect(reset["result"] == .bool(true))
            #expect(editor.expressions == ["Wink": 1])

            let unknown = try await call(
                makeService(), method: "pose.expressions.set", params: #"{"expressions": [{"name": "grin", "weight": 1}]}"#)
            let error = errorObject(of: unknown)
            #expect(error?.code == 1003)
            #expect(error?.dataCode == "expression_not_found")

            let outOfRange = try await call(
                makeService(), method: "pose.expressions.set", params: #"{"expressions": [{"name": "happy", "weight": 2}]}"#)
            guard case .object(let outOfRangeError)? = outOfRange["error"], case .int(let code)? = outOfRangeError["code"] else {
                Issue.record("Unexpected response: \(outOfRange)")
                return
            }
            #expect(code == -32602)
        }
    }

    @Test
    func poseExportAndSaveAsMotionUseTheClipSettings() async throws {
        let editor = MockPoseEditor()
        editor.isOpen = true
        try await withPoseEditor(editor) {
            let exported = try await call(makeService(), method: "pose.export", params: #"{"name": "peace", "duration": 3}"#)
            #expect(exported["result"] == .object(["vrma": .string(Data("peace@3.0".utf8).base64EncodedString())]))

            let defaulted = try await call(makeService(), method: "pose.export")
            #expect(defaulted["result"] == .object(["vrma": .string(Data("Pose@2.0".utf8).base64EncodedString())]))

            let saved = try await call(makeService(), method: "pose.saveAsMotion", params: #"{"name": "Peace", "loop": true}"#)
            #expect(saved["result"] == .object(["motionId": .string("vrma:Peace")]))
            #expect(editor.savedMotions.first?.isLoop == true)
            #expect(editor.savedMotions.first?.duration == 2)

            let applied = try await call(makeService(), method: "pose.apply")
            #expect(applied["result"] == .bool(true))
            #expect(editor.applyCount == 1)

            let closed = try await call(makeService(), method: "pose.close")
            #expect(closed["result"] == .bool(true))
            #expect(!editor.isOpen)
        }
    }

    @Test
    func unknownMethodReturnsMethodNotFound() async throws {
        let response = try await call(makeService(), method: "unknown.method")
        guard case .object(let error)? = response["error"], case .int(let code)? = error["code"] else {
            Issue.record("Unexpected response: \(response)")
            return
        }
        #expect(code == -32601)
    }

    @Test
    func structurallyInvalidRequestReturnsInvalidRequest() async throws {
        let body = Data(#"{"jsonrpc":"2.0","id":1}"#.utf8)
        let responseData = try #require(await VCamServer(handler: makeService()).handle(body))
        let response = try JSONDecoder().decode([String: JSONValue].self, from: responseData)
        guard case .object(let error)? = response["error"], case .int(let code)? = error["code"] else {
            Issue.record("Unexpected response: \(response)")
            return
        }
        #expect(code == -32600)
    }

    @Test
    func malformedJSONReturnsParseError() async throws {
        let body = Data(#"{"jsonrpc":"2.0","id":1"#.utf8)
        let responseData = try #require(await VCamServer(handler: makeService()).handle(body))
        let response = try JSONDecoder().decode([String: JSONValue].self, from: responseData)
        guard case .object(let error)? = response["error"], case .int(let code)? = error["code"] else {
            Issue.record("Unexpected response: \(response)")
            return
        }
        #expect(code == -32700)
    }
}

@MainActor
private struct MockTrackingProvider: TrackingControlling {
    var sources: [TrackingControl.Source] {
        [
            .init(id: "vcamMotion", status: .connected),
            .init(id: "vmcProtocol", status: .connecting),
            .init(id: "iFacialMocap", status: .disconnected),
        ]
    }
}

@MainActor
private final class MockSceneProvider: SceneControlling {
    var loadedSceneIds: [Int32] = []

    var sceneList: [SceneControl.Scene] {
        [.init(id: 1, name: "Main"), .init(id: 2, name: "Sub")]
    }

    var activeScene: SceneControl.Scene? {
        sceneList.first
    }

    func loadScene(id: Int32) async throws {
        loadedSceneIds.append(id)
    }

    var lighting: VCamScene.Lighting?
    var renamed: [(id: Int32, name: String)] = []
    var removedSceneIds: [Int32] = []

    func createScene(name: String?) async throws -> SceneControl.Scene {
        .init(id: 3, name: name ?? "New")
    }

    func duplicateScene(id: Int32, name: String?) async throws -> SceneControl.Scene {
        guard sceneList.contains(where: { $0.id == id }) else { throw SceneControlError.notFound }
        return .init(id: 4, name: name ?? "Copy")
    }

    func renameScene(id: Int32, name: String) throws {
        guard sceneList.contains(where: { $0.id == id }) else { throw SceneControlError.notFound }
        renamed.append((id, name))
    }

    func moveScene(id: Int32, toIndex index: Int) throws {}

    func removeScene(id: Int32) async throws {
        guard id != 1 else { throw SceneControlError.notRemovable }
        removedSceneIds.append(id)
    }

    func setLighting(_ lighting: VCamScene.Lighting?) throws {
        self.lighting = lighting
    }
}

@MainActor
private final class MockSceneObjectProvider: SceneObjectControlling {
    var objects: [SceneObjectControl.Object] = [
        .init(id: SceneObject.avatarID, kind: .avatar, name: "", isHidden: false, isLocked: false, placement: nil),
        .init(id: 1, kind: .text, name: "Title", isHidden: true, isLocked: false, placement: CGRect(x: 0.1, y: -0.2, width: 0.5, height: 0.25)),
    ]
    var changes: [(id: Int32, change: SceneObjectControl.Change)] = []
    var animations: [(id: Int32, placement: SceneObjectControl.PlacementChange, animation: ControlAnimation)] = []
    var addedTexts: [TextObjectConfiguration] = []
    var updatedTexts: [TextObjectConfiguration] = []
    var addedImageWasReadable: Bool?
    var addedWebs: [(url: URL, size: CGSize, fps: Int)] = []
    var subtitleStyle = SceneObjectControl.SubtitleStyle(configuration: .init(fontName: "Base"), x: 0, bottomY: -0.47, size: 1)
    var defaultTextConfiguration: TextObjectConfiguration { .init(fontName: "Default", fontSize: 100) }
    var textPresets: [SceneObjectControl.TextPreset] { [.init(id: "bold", name: "Bold")] }
    var fontNames: [String] { ["Base", "Default", "Preset", "Chosen"] }

    func update(id: Int32, change: SceneObjectControl.Change) throws {
        guard id != 99 else { throw SceneObjectControlError.notFound }
        guard id != 98 else { throw SceneObjectControlError.locked }
        changes.append((id, change))
    }

    func animatePlacement(id: Int32, placement: SceneObjectControl.PlacementChange, animation: ControlAnimation) async throws {
        guard id != 98 else { throw SceneObjectControlError.locked }
        animations.append((id, placement, animation))
    }

    var fades: [(id: Int32, isHidden: Bool, animation: ControlAnimation)] = []
    var animatedSubtitleStyles: [(style: SceneObjectControl.SubtitleStyle, animation: ControlAnimation)] = []

    func animateVisibility(id: Int32, isHidden: Bool, animation: ControlAnimation) async throws {
        fades.append((id, isHidden, animation))
    }

    func animateSubtitleStyle(_ style: SceneObjectControl.SubtitleStyle, animation: ControlAnimation) async {
        animatedSubtitleStyles.append((style, animation))
    }

    func move(id: Int32, toIndex index: Int) throws {}

    func duplicate(id: Int32) async throws -> Int32 {
        guard id != SceneObject.avatarID else { throw SceneObjectControlError.notDuplicable }
        return 2
    }

    func remove(id: Int32) throws {
        guard id != SceneObject.avatarID else { throw SceneObjectControlError.notRemovable }
    }

    func applyingTextPreset(id: String, to configuration: TextObjectConfiguration) throws -> TextObjectConfiguration {
        guard id == "bold" else { throw SceneObjectControlError.presetNotFound }
        var configuration = configuration
        configuration.fontName = "Preset"
        return configuration
    }

    func addText(_ configuration: TextObjectConfiguration) -> Int32 {
        addedTexts.append(configuration)
        return 5
    }

    func textConfiguration(id: Int32) throws -> TextObjectConfiguration {
        guard id != SceneObject.avatarID else { throw SceneObjectControlError.typeMismatch }
        return .init(text: "Hello", fontName: "Base", fontSize: 100)
    }

    func updateText(id: Int32, configuration: TextObjectConfiguration) throws {
        updatedTexts.append(configuration)
    }

    func setSubtitleStyle(_ style: SceneObjectControl.SubtitleStyle) {
        subtitleStyle = style
    }

    func addImage(fileURL: URL) throws -> Int32 {
        addedImageWasReadable = FileManager.default.contents(atPath: fileURL.path(percentEncoded: false)) == Data("image".utf8)
        return 6
    }

    func addWeb(url: URL, size: CGSize, fps: Int) -> Int32 {
        addedWebs.append((url, size, fps))
        return 7
    }

    func updateWeb(id: Int32, url: URL?, size: CGSize?, fps: Int?) throws {}

    var addedVideos: [(fileExtension: String, isLooping: Bool, isMuted: Bool)] = []
    var videoChanges: [(id: Int32, change: SceneObjectControl.VideoChange)] = []
    var acceptsVideos = true
    var videoError: SceneObjectControlError?

    func addVideo(fileURL: URL, isLooping: Bool, isMuted: Bool) async throws -> Int32 {
        guard acceptsVideos else { throw SceneObjectControlError.invalidVideo }
        addedVideos.append((fileURL.pathExtension, isLooping, isMuted))
        return 8
    }

    func videoState(id: Int32) async throws -> SceneObjectControl.VideoState {
        if let videoError { throw videoError }
        return .init(duration: 2.5, time: 0, isPlaying: true, isLooping: true, isMuted: true)
    }

    func updateVideo(id: Int32, change: SceneObjectControl.VideoChange) throws {
        videoChanges.append((id, change))
    }
}

@MainActor
private final class MockPoseEditor: PoseEditing {
    /// Whether the editor has opened and loaded the avatar. While closed everything
    /// but `open` throws `editorNotOpen`, matching the real editor
    var isOpen = false
    var pose: [String: PoseControl.JointPose] = [:]
    var expressions: [String: Float] = [:]
    var savedMotions: [(name: String, duration: Float, isLoop: Bool)] = []
    var applyCount = 0

    private let bones = ["hips", "leftUpperArm", "leftHand"]
    private let movableBones = ["hips", "leftHand"]
    private let expressionNames = ["happy", "Wink"]
    var effectors: [String: SIMD3<Float>] = ["hips": SIMD3(0, 1, 0), "leftHand": SIMD3(0.6, 1.3, 0)]
    var movedWithPlantedFeet: Bool?

    func open() async throws -> PoseControl.Rig {
        isOpen = true
        return PoseControl.Rig(bones: bones, movableBones: movableBones, expressions: expressionNames)
    }

    func close() {
        isOpen = false
    }

    func currentPose() throws -> [PoseControl.JointPose] {
        try requireOpen()
        return bones.compactMap { bone in
            pose[bone].map { PoseControl.JointPose(bone: bone, rotation: $0.rotation, position: $0.position, effector: effectors[bone]) }
        }
    }

    func movePose(_ targets: [PoseControl.JointTarget], plantsFeet: Bool) throws -> [PoseControl.JointPose] {
        try requireOpen()
        for target in targets {
            guard bones.contains(target.bone) else { throw PoseControlError.boneNotFound(target.bone) }
            guard movableBones.contains(target.bone) else { throw PoseControlError.boneNotMovable(target.bone) }
        }
        movedWithPlantedFeet = plantsFeet
        for target in targets {
            effectors[target.bone] = target.position
            // The solver writes rotations of its own; a fixed value stands in for them
            pose[target.bone] = PoseControl.JointPose(bone: target.bone, rotation: SIMD3(0, 0, 45))
        }
        return try currentPose()
    }

    func setPose(_ joints: [PoseControl.JointPose]) throws {
        try requireOpen()
        for joint in joints {
            guard bones.contains(joint.bone) else { throw PoseControlError.boneNotFound(joint.bone) }
        }
        for joint in joints {
            pose[joint.bone] = joint
        }
    }

    func resetPose(bones: [String]?) throws {
        try requireOpen()
        for bone in bones ?? self.bones {
            guard self.bones.contains(bone) else { throw PoseControlError.boneNotFound(bone) }
            pose[bone] = nil
        }
    }

    func currentExpressions() throws -> [PoseControl.ExpressionWeight] {
        try requireOpen()
        return expressionNames.map { PoseControl.ExpressionWeight(name: $0, weight: expressions[$0] ?? 0) }
    }

    func setExpressions(_ weights: [PoseControl.ExpressionWeight]) throws {
        try requireOpen()
        for weight in weights {
            guard expressionNames.contains(weight.name) else { throw PoseControlError.expressionNotFound(weight.name) }
        }
        for weight in weights {
            expressions[weight.name] = weight.weight
        }
    }

    func resetExpressions(names: [String]?) throws {
        try requireOpen()
        for name in names ?? expressionNames {
            guard expressionNames.contains(name) else { throw PoseControlError.expressionNotFound(name) }
            expressions[name] = nil
        }
    }

    func applyToAvatar() async throws {
        try requireOpen()
        applyCount += 1
    }

    func exportAnimation(name: String, duration: Float) throws -> Data {
        try requireOpen()
        return Data("\(name)@\(duration)".utf8)
    }

    func addToMotions(name: String, duration: Float, isLoop: Bool) async throws -> String {
        try requireOpen()
        savedMotions.append((name, duration, isLoop))
        return "vrma:\(name)"
    }

    private func requireOpen() throws {
        guard isOpen else { throw PoseControlError.editorNotOpen }
    }
}
