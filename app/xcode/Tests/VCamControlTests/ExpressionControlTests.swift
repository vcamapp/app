import Testing
@testable import VCamBridge
import VCamControl
import VCamData

extension RecordingWhileSuspendedTests {
    @MainActor
    @Suite
    struct ExpressionControlTests {
        private func appliedNames(during body: () -> Void) -> [String] {
            recordedMethodCalls({ method, payload in
                method == .applyExpression ? String(cString: payload!.assumingMemoryBound(to: CChar.self)) : nil
            }, during: body)
        }

        @Test
        func applySendsExpressionName() {
            let state = UniState()

            let applied = appliedNames {
                ExpressionControl.apply(name: "Joy", state: state)
            }

            #expect(applied == ["Joy"])
            #expect(state.currentExpressionName == "Joy")
        }

        @Test
        func applyingTheCurrentExpressionKeepsIt() {
            let state = UniState()
            state.currentExpressionName = "Joy"

            let applied = appliedNames {
                ExpressionControl.apply(name: "Joy", state: state)
            }

            #expect(applied == ["Joy"])
            #expect(state.currentExpressionName == "Joy")
        }

        @Test
        func applyingAnotherExpressionReplacesIt() {
            let state = UniState()
            state.currentExpressionName = "Joy"

            let applied = appliedNames {
                ExpressionControl.apply(name: "Angry", state: state)
            }

            #expect(applied == ["Angry"])
            #expect(state.currentExpressionName == "Angry")
        }

        @Test
        func clearTakesTheExpressionOff() {
            let state = UniState()
            state.currentExpressionName = "Joy"

            let applied = appliedNames {
                ExpressionControl.clear(state: state)
            }

            #expect(applied == [""])
            #expect(state.currentExpressionName == nil)
        }

        @Test
        func togglingTheCurrentExpressionClearsIt() {
            let state = UniState()
            state.currentExpressionName = "Joy"

            let applied = appliedNames {
                ExpressionControl.toggle(name: "Joy", state: state)
            }

            #expect(applied == [""])
            #expect(state.currentExpressionName == nil)
        }

        @Test
        func togglingAnotherExpressionReplacesIt() {
            let state = UniState()
            state.currentExpressionName = "Joy"

            let applied = appliedNames {
                ExpressionControl.toggle(name: "Angry", state: state)
            }

            #expect(applied == ["Angry"])
            #expect(state.currentExpressionName == "Angry")
        }

        @Test
        func gazeSendsItsTarget() {
            let calls = recordedMethodCalls({ method, payload in
                method == .setGaze ? payload?.load(as: GazePayload.self) : nil
            }) {
                GazeControl.look(at: .direction(yaw: 30, pitch: -5), movesHead: false)
                GazeControl.look(at: .camera, movesHead: true)
                GazeControl.look(at: .auto, movesHead: true)
            }

            #expect(calls.map(\.mode) == [GazeMode.direction, .camera, .auto].map(\.rawValue))
            #expect(calls[0].yaw == 30)
            #expect(calls[0].pitch == -5)
            #expect(calls[0].movesHead == 0)
            #expect(calls[1].movesHead == 1)
        }
    }
}

extension RecordingWhileSuspendedTests {
    @MainActor
    @Suite
    struct ExpressionControlFadeTests {
        private func recordedTransitions(during body: () async -> Void) async -> [(expressions: [String: Float], duration: Float, easing: Int32)] {
            nonisolated(unsafe) var transitions: [(expressions: [String: Float], duration: Float, easing: Int32)] = []
            let originalCallback = UniBridge.methodCallback
            defer {
                UniBridge.methodCallback = originalCallback
            }
            UniBridge.methodCallback = { method, payload, _ in
                if method == .applyExpressionTransition, let payload {
                    let call = payload.load(as: ExpressionTransitionPayload.self)
                    transitions.append((call.expressions, call.duration, call.easing))
                }
            }
            await body()
            return transitions
        }

        @Test
        func aWeightGoesToTheRendererWithoutAFade() async {
            let state = UniState()

            let transitions = await recordedTransitions {
                await ExpressionControl.apply([.init(name: "Joy", weight: 0.5)], animation: nil, state: state)
            }

            #expect(transitions.count == 1)
            #expect(transitions.first?.expressions == ["Joy": 0.5])
            #expect(transitions.first?.duration == 0)
            #expect(state.currentExpressionName == "Joy")
        }

        @Test
        func aFadeGoesToTheRendererAndWaitsForItsEnd() async {
            let state = UniState()
            let start = ContinuousClock.now

            let transitions = await recordedTransitions {
                await ExpressionControl.apply([.init(name: "Joy", weight: 1)], animation: .init(duration: 0.05, easing: .easeOut), state: state)
            }

            #expect(ContinuousClock.now - start >= .milliseconds(50))
            #expect(transitions.first?.duration == 0.05)
            #expect(transitions.first?.easing == TransitionEasing.easeOut.rawValue)
        }

        @Test
        func aFullWeightWithoutAFadeUsesThePlainPath() async {
            let state = UniState()

            let transitions = await recordedTransitions {
                await ExpressionControl.apply([.init(name: "Joy", weight: 1)], animation: nil, state: state)
            }

            #expect(transitions.isEmpty)
            #expect(state.currentExpressionName == "Joy")
        }

        @Test
        func everyExpressionOfAMixReachesTheRenderer() async {
            let state = UniState()
            let mix = [AppliedExpression(name: "笑顔", weight: 0.7), AppliedExpression(name: "a=b,c", weight: 0.3)]

            let transitions = await recordedTransitions {
                await ExpressionControl.apply(mix, animation: nil, state: state)
            }

            #expect(transitions.first?.expressions == ["笑顔": 0.7, "a=b,c": 0.3])
            #expect(state.currentExpressions == mix)
            #expect(state.currentExpressionName == "笑顔")
        }

        @Test
        func aWeightOfZeroIsNotApplied() async {
            let state = UniState()

            let transitions = await recordedTransitions {
                await ExpressionControl.apply([.init(name: "Joy", weight: 0.5), .init(name: "Angry", weight: 0)], animation: nil, state: state)
            }

            #expect(transitions.first?.expressions == ["Joy": 0.5])
            #expect(state.currentExpressions == [.init(name: "Joy", weight: 0.5)])
        }

        @Test
        func clearingWithAFadeReportsNoExpressionFromTheStart() async {
            let state = UniState()
            state.currentExpressionName = "Joy"

            let transitions = await recordedTransitions {
                await ExpressionControl.apply([], animation: .init(duration: 0.03, easing: .linear), state: state)
            }

            #expect(transitions.first?.expressions == [:])
            #expect(transitions.first?.duration == 0.03)
            #expect(state.currentExpressionName == nil)
        }
    }
}
