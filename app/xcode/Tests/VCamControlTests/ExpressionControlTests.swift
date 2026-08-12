import Testing
@testable import VCamBridge
import VCamControl

@MainActor
@Suite
struct ExpressionControlTests {
    @Test
    func applySendsExpressionName() {
        let applied = recordedMethodCalls({ method, payload in
            method == .applyExpression ? String(cString: payload!.assumingMemoryBound(to: CChar.self)) : nil
        }, during: {
            ExpressionControl.apply(name: "Joy")
        })
        #expect(applied == ["Joy"])
    }
}
