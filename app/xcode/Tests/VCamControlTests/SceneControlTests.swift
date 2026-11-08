import Foundation
import Testing
import VCamControl
import VCamEntity

// Serialized: these swap the global transition and suspend while it runs
@MainActor
@Suite(.serialized)
struct SceneControlTests {
    private final class Recorder {
        var events: [String] = []
        var opacities: [Float] = []
    }

    private final class MockTransition: SceneTransitionPresenting {
        let recorder: Recorder
        let canHold: Bool

        init(recorder: Recorder, canHold: Bool = true) {
            self.recorder = recorder
            self.canHold = canHold
        }

        func holdCurrentFrame() -> Bool {
            recorder.events.append("hold")
            return canHold
        }

        func setHeldFrameOpacity(_ opacity: Float) {
            recorder.opacities.append(opacity)
        }

        func releaseHeldFrame() {
            recorder.events.append("release")
        }
    }

    private struct LoadError: Error {}

    private final class MockProvider: SceneControlling {
        let recorder: Recorder
        var failsToLoad = false

        init(recorder: Recorder) {
            self.recorder = recorder
        }

        var sceneList: [SceneControl.Scene] { [] }
        var activeScene: SceneControl.Scene? { nil }
        var lighting: VCamScene.Lighting? { nil }

        func loadScene(id: Int32) async throws {
            recorder.events.append("load \(id)")
            if failsToLoad {
                throw LoadError()
            }
        }

        func createScene(name: String?) async throws -> SceneControl.Scene { .init(id: 0, name: "") }
        func duplicateScene(id: Int32, name: String?) async throws -> SceneControl.Scene { .init(id: 0, name: "") }
        func renameScene(id: Int32, name: String) throws {}
        func moveScene(id: Int32, toIndex index: Int) throws {}
        func removeScene(id: Int32) async throws {}
        func setLighting(_ lighting: VCamScene.Lighting?) throws {}
    }

    private func withTransition(_ transition: (any SceneTransitionPresenting)?, _ body: () async throws -> Void) async rethrows {
        let original = SceneControl.transition
        defer {
            SceneControl.transition = original
        }
        SceneControl.transition = transition
        try await body()
    }

    private let animation = ControlAnimation(duration: 0.05, easing: .linear)

    @Test
    func aCrossfadeHoldsTheFrameUntilItHasFadedOut() async throws {
        let recorder = Recorder()
        try await withTransition(MockTransition(recorder: recorder)) {
            try await SceneControl.loadScene(id: 1, animation: animation, on: MockProvider(recorder: recorder))
        }

        #expect(recorder.events == ["hold", "load 1", "release"])
        #expect(recorder.opacities.count > 1)
        #expect(recorder.opacities.last == 0)
        #expect(zip(recorder.opacities, recorder.opacities.dropFirst()).allSatisfy { $0 >= $1 })
    }

    @Test
    func withoutAnAnimationTheFrameIsHeldUntilTheSceneHasLoaded() async throws {
        let recorder = Recorder()
        try await withTransition(MockTransition(recorder: recorder)) {
            try await SceneControl.loadScene(id: 1, animation: nil, on: MockProvider(recorder: recorder))
        }

        #expect(recorder.events == ["hold", "load 1", "release"])
        #expect(recorder.opacities.isEmpty)
    }

    @Test
    func anAppWithoutTransitionsSwitchesAtOnce() async throws {
        let recorder = Recorder()
        try await withTransition(nil) {
            try await SceneControl.loadScene(id: 1, animation: animation, on: MockProvider(recorder: recorder))
        }

        #expect(recorder.events == ["load 1"])
    }

    @Test
    func aFrameThatCannotBeHeldSwitchesAtOnce() async throws {
        let recorder = Recorder()
        try await withTransition(MockTransition(recorder: recorder, canHold: false)) {
            try await SceneControl.loadScene(id: 1, animation: animation, on: MockProvider(recorder: recorder))
        }

        #expect(recorder.events == ["hold", "release", "load 1"])
        #expect(recorder.opacities.isEmpty)
    }

    @Test
    func aFailedLoadReleasesTheFrame() async {
        let recorder = Recorder()
        let provider = MockProvider(recorder: recorder)
        provider.failsToLoad = true
        await withTransition(MockTransition(recorder: recorder)) {
            await #expect(throws: LoadError.self) {
                try await SceneControl.loadScene(id: 1, animation: animation, on: provider)
            }
        }

        #expect(recorder.events == ["hold", "load 1", "release"])
    }

    @Test
    func aNewLoadTakesOverAndReleasesOnce() async throws {
        let recorder = Recorder()
        let provider = MockProvider(recorder: recorder)
        try await withTransition(MockTransition(recorder: recorder)) {
            let first = Task { @MainActor in
                try await SceneControl.loadScene(id: 1, animation: .init(duration: 10, easing: .linear), on: provider)
            }
            try? await Task.sleep(for: .milliseconds(150))
            try await SceneControl.loadScene(id: 2, animation: animation, on: provider)
            try await first.value
        }

        #expect(recorder.events == ["hold", "load 1", "hold", "load 2", "release"])
        #expect(recorder.opacities.last == 0)
    }
}
