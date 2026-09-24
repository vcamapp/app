import Testing
@testable import VCamData

/// A default scene has to land in the orientation it was made for. When it took the current
/// output's ratio instead, the portrait slot stayed empty and every launch added another scene
@Suite
struct VCamSceneAspectRatioTests {
    private static let landscape: Float = 1080 / 1920
    private static let portrait: Float = 1920 / 1080

    @Test
    func keepsCurrentRatioForCurrentOrientation() {
        #expect(VCamSceneDataStore.aspectRatio(isLandscape: true, currentAspectRatio: Self.landscape) == Self.landscape)
        #expect(VCamSceneDataStore.aspectRatio(isLandscape: false, currentAspectRatio: Self.portrait) == Self.portrait)
    }

    @Test
    func usesOtherOrientationRatioWhileOutputtingTheOther() {
        #expect(VCamSceneDataStore.aspectRatio(isLandscape: false, currentAspectRatio: Self.landscape) > 1)
        #expect(VCamSceneDataStore.aspectRatio(isLandscape: true, currentAspectRatio: Self.portrait) <= 1)
    }
}
