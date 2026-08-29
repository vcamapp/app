import Testing
@testable import VCamBridge
import VCamControl
import VCamData

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

    /// The picker has no separate clear button: selecting the current expression turns it off
    @Test
    func applyingTheCurrentExpressionClearsIt() {
        let state = UniState()
        state.currentExpressionName = "Joy"

        let applied = appliedNames {
            ExpressionControl.apply(name: "Joy", state: state)
        }

        #expect(applied == [""])
        #expect(state.currentExpressionName == nil)
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
}
