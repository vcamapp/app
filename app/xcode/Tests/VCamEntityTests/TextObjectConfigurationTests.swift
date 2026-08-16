import Testing
@testable import VCamEntity

@Suite
struct TextObjectConfigurationTests {
    @Test
    func fontSizeIsConstrainedToRenderingRange() {
        #expect(TextObjectConfiguration.normalizedFontSize(0) == TextObjectConfiguration.fontSizeRange.lowerBound)
        #expect(TextObjectConfiguration.normalizedFontSize(-1) == TextObjectConfiguration.fontSizeRange.lowerBound)
        #expect(TextObjectConfiguration.normalizedFontSize(2048) == TextObjectConfiguration.fontSizeRange.upperBound)
        #expect(TextObjectConfiguration.normalizedFontSize(.infinity) == TextObjectConfiguration.defaultFontSize)
        #expect(TextObjectConfiguration.normalizedFontSize(.nan) == TextObjectConfiguration.defaultFontSize)
    }

    @Test
    func initializerNormalizesFontSize() {
        #expect(TextObjectConfiguration(fontSize: 0).fontSize == TextObjectConfiguration.fontSizeRange.lowerBound)
    }
}
