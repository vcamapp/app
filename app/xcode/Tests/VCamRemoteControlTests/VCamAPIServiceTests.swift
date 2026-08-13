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

    /// Feeds one request into the generated server and decodes the response
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
        #expect(result["apiVersion"] == .string("0.1.0"))
        #expect(APISpecification.apiVersion == "0.1.0")
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
        var played: [(id: String, isLoop: Bool)] = []
        let originalCallback = UniBridge.methodCallback
        defer {
            UniBridge.methodCallback = originalCallback
        }
        UniBridge.methodCallback = { method, payload, _ in
            if method == .playMotion {
                let payload = payload!.load(as: PlayMotionPayload.self)
                played.append((id: String(cString: payload.stringPtr!), isLoop: payload.isLoop == 1))
            }
        }

        let motionID = MotionID.builtIn(name: "hi").rawValue
        let response = try await call(
            makeService(), method: "motion.play", params: #"{"motionId": "\#(motionID)"}"#)

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
        let model = Models.Model(name: "internal-name", displayName: "Ada", type: .vrm)
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
        var applied: [String] = []
        let originalCallback = UniBridge.methodCallback
        defer {
            UniBridge.methodCallback = originalCallback
        }
        UniBridge.methodCallback = { method, payload, _ in
            if method == .applyExpression {
                applied.append(String(cString: payload!.assumingMemoryBound(to: CChar.self)))
            }
        }

        let uniState = UniState()
        uniState.expressions = [.init(name: "Joy")]
        let service = makeService(uniState: uniState)

        let success = try await call(service, method: "expression.set", params: #"{"name": "Joy"}"#)
        #expect(success["result"] == .bool(true))
        #expect(applied == ["Joy"])

        let failure = try await call(service, method: "expression.set", params: #"{"name": "Angry"}"#)
        #expect(errorObject(of: failure)?.code == 1003)
    }

    @Test
    func sceneGetReportsNotReadyWithoutProvider() async throws {
        let originalProvider = SceneControl.provider
        defer {
            SceneControl.provider = originalProvider
        }
        SceneControl.provider = nil

        let response = try await call(makeService(), method: "scene.get")
        let error = errorObject(of: response)
        #expect(error?.code == 1000)
        #expect(error?.dataCode == "not_ready")
    }

    @Test
    func sceneLoadDelegatesToProvider() async throws {
        let originalProvider = SceneControl.provider
        defer {
            SceneControl.provider = originalProvider
        }
        let provider = SceneProviderMock()
        SceneControl.provider = provider

        let success = try await call(makeService(), method: "scene.load", params: #"{"sceneId": 2}"#)
        #expect(success["result"] == .bool(true))
        #expect(provider.loadedSceneIds == [2])

        let failure = try await call(makeService(), method: "scene.load", params: #"{"sceneId": 99}"#)
        #expect(errorObject(of: failure)?.code == 1004)
        #expect(provider.loadedSceneIds == [2])
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
private final class SceneProviderMock: SceneControlling {
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
