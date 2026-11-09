import Testing
@testable import VCamBridge
import VCamControl

extension RecordingWhileSuspendedTests {
    @MainActor
    @Suite
    struct CameraControlTests {
        @Test
        func resetCameraFiresTrigger() {
            let triggered = recordedTriggers {
                CameraControl.resetCamera()
            }
            #expect(triggered == [.resetCamera])
        }

        @Test
        func cameraControlSendsTypedPayload() {
            let calls = recordedMethodCalls({ method, payload in
                method == .cameraControl ? payload?.load(as: CameraControlPayload.self) : nil
            }) {
                UniBridge.cameraControl(.orbit, dx: 12, dy: -3)
            }
            #expect(calls.count == 1)
            #expect(calls.first?.intent == CameraControlIntent.orbit.rawValue)
            #expect(calls.first?.dx == 12)
            #expect(calls.first?.dy == -3)
        }
    }
}

extension RecordingWhileSuspendedTests {
    @MainActor
    @Suite
    struct CameraControlAdjustTests {
        private func recordedCameraCalls(during body: () async -> Void) async -> [CameraControlPayload] {
            nonisolated(unsafe) var calls: [CameraControlPayload] = []
            let originalCallback = UniBridge.methodCallback
            defer {
                UniBridge.methodCallback = originalCallback
            }
            UniBridge.methodCallback = { method, payload, _ in
                if method == .cameraControl, let payload {
                    calls.append(payload.load(as: CameraControlPayload.self))
                }
            }
            await body()
            return calls
        }

        private func total(of calls: [CameraControlPayload], _ intent: CameraControlIntent) -> Float {
            calls.filter { $0.intent == intent.rawValue }.map(\.dx).reduce(0, +)
        }

        private func commitCount(in calls: [CameraControlPayload]) -> Int {
            calls.filter { $0.intent == CameraControlIntent.commit.rawValue }.count
        }

        @Test
        func anAdjustmentWithoutAnimationAppliesAtOnce() async {
            let calls = await recordedCameraCalls {
                await CameraControl.adjust(.init(panX: 0.5, zoom: 2))
            }

            #expect(calls.map(\.intent) == [CameraControlIntent.pan, .magnify, .commit].map(\.rawValue))
            #expect(calls[0].dx == 0.5)
            #expect(calls[1].dx == 2)
        }

        @Test
        func anAnimationSpreadsTheSameTotalOverFrames() async {
            let calls = await recordedCameraCalls {
                await CameraControl.adjust(.init(panX: 0.5, zoom: 4), animation: .init(duration: 0.05, easing: .easeInOut))
            }

            let magnifications = calls.filter { $0.intent == CameraControlIntent.magnify.rawValue }.map(\.dx)
            #expect(magnifications.count > 1)
            #expect(abs(magnifications.reduce(1, *) - 4) < 0.001)
            #expect(abs(total(of: calls, .pan) - 0.5) < 0.001)
            #expect(calls.last?.intent == CameraControlIntent.commit.rawValue)
            #expect(commitCount(in: calls) == 1)
        }

        @Test
        func anotherAdjustmentTakesOverAndSavesOnce() async {
            let calls = await recordedCameraCalls {
                let first = Task { @MainActor in
                    await CameraControl.adjust(.init(panX: 100), animation: .init(duration: 10, easing: .linear))
                }
                try? await Task.sleep(for: .milliseconds(40))
                await CameraControl.adjust(.init(panX: 1))
                await first.value
            }

            #expect(total(of: calls, .pan) < 10)
            #expect(commitCount(in: calls) == 1)
        }
    }
}

extension RecordingWhileSuspendedTests {
    @MainActor
    @Suite
    struct CameraControlViewTests {
        /// Stands in for the engine: reading answers `current`, and every view sent becomes the current one
        private final class EngineCamera {
            var current: [Float]
            var sent: [[Float]] = []

            init(_ view: CameraControl.View) {
                current = [view.position.x, view.position.y, view.position.z, view.rotation.x, view.rotation.y, view.rotation.z, view.zoom]
            }
        }

        private func withEngineCamera(_ camera: EngineCamera, during body: () async -> Void) async -> [CameraControlPayload] {
            nonisolated(unsafe) var commits: [CameraControlPayload] = []
            let mapper = UniBridge.shared.arrayMapper
            let originalGetValue = mapper.getValue
            let originalSetValue = mapper.setValue
            let originalCallback = UniBridge.methodCallback
            defer {
                mapper.getValue = originalGetValue
                mapper.setValue = originalSetValue
                UniBridge.methodCallback = originalCallback
            }
            let storage = UnsafeMutablePointer<Float>.allocate(capacity: 7)
            defer {
                storage.deallocate()
            }
            mapper.getValue = { _ in
                for (index, value) in camera.current.enumerated() {
                    storage[index] = value
                }
                return UnsafeMutableRawPointer(storage)
            }
            mapper.setValue = { type, value in
                guard type == .objectAvatarTransform else { return }
                let values = Array(UnsafeBufferPointer(start: value.assumingMemoryBound(to: Float.self), count: 7))
                camera.sent.append(values)
                camera.current = values
            }
            UniBridge.methodCallback = { method, payload, _ in
                if method == .cameraControl, let payload {
                    commits.append(payload.load(as: CameraControlPayload.self))
                }
            }
            await body()
            return commits
        }

        private let start = CameraControl.View(position: SIMD3(0, 1, -3), rotation: SIMD3(10, 350, 0), zoom: 1)
        private let target = CameraControl.View(position: SIMD3(1, 1.5, -2), rotation: SIMD3(0, 20, 0), zoom: 2)

        @Test
        func theViewIsReadFromTheEngine() async {
            let camera = EngineCamera(start)
            _ = await withEngineCamera(camera) {
                #expect(CameraControl.view == start)
            }
        }

        @Test
        func aViewWithoutAnimationIsSentOnceAndSaved() async {
            let camera = EngineCamera(start)
            let calls = await withEngineCamera(camera) {
                await CameraControl.set(target)
            }

            #expect(camera.sent == [[1, 1.5, -2, 0, 20, 0, 2]])
            #expect(calls.map(\.intent) == [CameraControlIntent.commit.rawValue])
        }

        @Test
        func anAnimationEndsAtTheViewAndSavesOnce() async {
            let camera = EngineCamera(start)
            let calls = await withEngineCamera(camera) {
                await CameraControl.set(target, animation: .init(duration: 0.05, easing: .easeInOut))
            }

            #expect(camera.sent.count > 1)
            #expect(camera.sent.last == [1, 1.5, -2, 0, 380, 0, 2])
            #expect(calls.map(\.intent) == [CameraControlIntent.commit.rawValue])
        }

        @Test
        func turnsTakeTheShortWayRound() {
            let halfway = start.interpolated(to: target, progress: 0.5)

            // From 350 to 20 degrees turns 30 degrees through 0, not 330 degrees back
            #expect(abs(halfway.rotation.y - 365) < 0.001)
            #expect(abs(halfway.rotation.x - 5) < 0.001)
            #expect(halfway.position == SIMD3(0.5, 1.25, -2.5))
        }

        @Test
        func theZoomChangesByASteadyRatio() {
            let halfway = start.interpolated(to: target, progress: 0.5)

            #expect(abs(halfway.zoom - Float(2).squareRoot()) < 0.001)
        }
    }
}
