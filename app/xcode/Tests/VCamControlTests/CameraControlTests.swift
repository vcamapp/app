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
