import Testing
@testable import VCamRemoteControl

struct ExternalControlTokenTests {
    @Test
    func generatesURLSafeTokens() {
        let token = ExternalControlToken.generate()
        #expect(token.count == 43)
        #expect(token.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
        #expect(token != ExternalControlToken.generate())
    }

    @Test
    func authorizesOnlyTheBearerToken() {
        #expect(ExternalControlToken.authorizes([(name: "authorization", value: "Bearer abc")], token: "abc"))
        #expect(!ExternalControlToken.authorizes([(name: "Authorization", value: "Bearer abd")], token: "abc"))
        #expect(!ExternalControlToken.authorizes([(name: "Authorization", value: "Bearer abcd")], token: "abc"))
        #expect(!ExternalControlToken.authorizes([(name: "Authorization", value: "abc")], token: "abc"))
        #expect(!ExternalControlToken.authorizes([(name: "X-Token", value: "Bearer abc")], token: "abc"))
    }
}
