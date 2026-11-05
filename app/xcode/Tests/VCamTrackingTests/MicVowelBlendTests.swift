import Testing
import VCamEntity
import VCamTrackingCore

@Suite
struct MicVowelBlendTests {
    private static func total(_ blend: MicVowelBlend) -> Float {
        Vowel.allCases.reduce(0) { $0 + blend.weight(of: $1) }
    }

    @Test
    func crossFadesInsteadOfJumping() {
        var blend = MicVowelBlend()
        blend.update(toward: .i, deltaTime: 1.0 / 60)
        #expect(blend.weight(of: .i) > 0)
        #expect(blend.weight(of: .i) < 0.5)
        #expect(blend.weight(of: .a) > 0.5)

        for _ in 0..<60 {
            blend.update(toward: .i, deltaTime: 1.0 / 60)
        }
        #expect(blend.weight(of: .i) > 0.99)
    }

    /// The mouth would shrink or grow during a change if the weights did not sum to 1
    @Test
    func keepsTheTotalWeightWhileChanging() {
        var blend = MicVowelBlend()
        for vowel in [Vowel.i, .o, .e, .u, .a] {
            for _ in 0..<4 {
                blend.update(toward: vowel, deltaTime: 1.0 / 60)
                #expect(abs(Self.total(blend) - 1) < 0.001)
            }
        }
    }
}
