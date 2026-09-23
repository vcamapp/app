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

    private func makeService(
        connectionID: UUID = UUID(),
        modelManager: ModelManager = ModelManager(models: []),
        uniState: UniState = UniState(),
        eventPublisher: EventPublisher = EventPublisher()
    ) -> VCamAPIService {
        VCamAPIService(
            connectionID: connectionID,
            modelManager: modelManager,
            motionLibrary: Self.library,
            uniState: uniState,
            eventPublisher: eventPublisher
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
            success = try await call(service, method: "expression.set", params: #"{"name": "Joy"}"#)
        }
        #expect(success["result"] == .bool(true))
        #expect(applied == ["Joy"])

        let failure = try await call(service, method: "expression.set", params: #"{"name": "Angry"}"#)
        #expect(errorObject(of: failure)?.code == 1003)
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
