import Testing
import Vision
import VCamBridge
import VCamMotionV1
@testable import VCamTracking

@Suite
struct VCamMotionTests {
    @Test
    func decodeRawData() {
        let handRawData = VCamMotion.Hand(wrist: .init(1, 2), thumbCMC: .init(3, 4), littleMCP: .init(5, 6), thumbTip: .init(7, 8), indexTip: .init(9, 10), middleTip: .init(11, 12), ringTip: .init(13, 14), littleTip: .init(15, 16))
        var blendShape = BlendShape(lookAtPoint: .init(1, 2))
        for (index, keyPath) in BlendShape.wireOrder.enumerated() {
            blendShape[keyPath: keyPath] = Float(index + 1)
        }
        var testRawData = VCamMotion(version: 123, head: .init(translation: .init(1, 2, 3), rotation: .init(ix: 1, iy: 2, iz: 3, r: 4)), hands: .init(right: handRawData, left: handRawData), blendShape: blendShape)

        let encodedData = testRawData.dataNoCopy()
        let decodedData = VCamMotion(rawData: encodedData)
        #expect(testRawData == decodedData)
    }

    @Test
    func invertedTrackingInputRangeScalesInReverse() {
        let entry = TrackingMappingEntry(
            input: .init(key: "_posY", bounds: -1...1, rangeMin: 1, rangeMax: -1),
            outputKey: .init(key: "_posY", bounds: -1...1)
        )

        #expect(entry.scaleValue(1) == -1)
        #expect(entry.scaleValue(0) == 0)
        #expect(entry.scaleValue(-1) == 1)
    }

    @Test
    func reverseDirectionFlipsOnlyTheGivenSide() {
        var entry = TrackingMappingEntry(
            input: .init(key: "_posY", bounds: -1...1, rangeMin: -1, rangeMax: 1),
            outputKey: .init(key: "_posY", bounds: -1...1, rangeMin: -1, rangeMax: 1)
        )

        entry.reverseDirection(.input)

        #expect(entry.input.rangeMin == 1)
        #expect(entry.input.rangeMax == -1)
        #expect(entry.outputKey.rangeMin == -1)
        #expect(entry.outputKey.rangeMax == 1)

        entry.reverseDirection(.output)

        #expect(entry.outputKey.rangeMin == 1)
        #expect(entry.outputKey.rangeMax == -1)
    }

    @Test
    func updateBoundsKeepsInvertedRange() {
        var entry = TrackingMappingEntry(
            input: .init(key: "_posY", bounds: -1...1, rangeMin: 1, rangeMax: -1),
            outputKey: .init(key: "_posY", bounds: -1...1, rangeMin: -1, rangeMax: 1)
        )

        entry.updateBounds(-0.5...0.5, for: .input)

        #expect(entry.input.bounds == -0.5...0.5)
        #expect(entry.input.rangeMin == 0.5)
        #expect(entry.input.rangeMax == -0.5)
        #expect(entry.outputKey.bounds == -1...1)
    }

    @Test
    func updateBoundsKeepsCollapsedRangeDisabled() {
        var entry = TrackingMappingEntry(
            input: .init(key: "_posY", bounds: -1...1),
            outputKey: .init(key: "_posY", bounds: -1...1, rangeMin: 0, rangeMax: 0)
        )

        entry.updateBounds(-0.5...0.5, for: .output)

        #expect(entry.outputKey.bounds == -0.5...0.5)
        #expect(entry.outputKey.rangeMin == 0)
        #expect(entry.outputKey.rangeMax == 0)
    }

    @Test
    func updateBoundsKeepsInvertedDirectionWhenClamped() {
        var entry = TrackingMappingEntry(
            input: .init(key: "_posY", bounds: -1...1, rangeMin: 1, rangeMax: -1),
            outputKey: .init(key: "_posY", bounds: -1...1)
        )

        entry.updateBounds(2...3, for: .input)

        #expect(entry.input.rangeMin == 3)
        #expect(entry.input.rangeMax == 2)
    }

    @Test
    func perfectSyncPositionYAndZDefaultOutputRangeIsDisabled() throws {
        let mappings = TrackingMappingEntry.defaultMappings(for: .perfectSync)

        for key in ["_posY", "_posZ"] {
            let mapping = try #require(mappings.first { $0.input.key == key })
            #expect(mapping.outputKey.rangeMin == 0)
            #expect(mapping.outputKey.rangeMax == 0)
        }
    }

    @Test
    func resetToDefaultDisablesPositionYAndZOutputRange() {
        var entry = TrackingMappingEntry(
            input: .init(key: "_posY", bounds: -1...1, rangeMin: -0.5, rangeMax: 0.5),
            outputKey: .init(key: "_posY", bounds: -1...1, rangeMin: -1, rangeMax: 1)
        )

        entry.resetToDefault(for: .perfectSync)

        #expect(entry.outputKey.rangeMin == 0)
        #expect(entry.outputKey.rangeMax == 0)
    }

    @Test
    func webCameraPositionYAndZDefaultOutputRangeIsDisabled() throws {
        let mappings = TrackingMappingEntry.defaultMappings(for: .blendShape)

        let posXMapping = try #require(mappings.first { $0.input.key == "_posX" })
        #expect(posXMapping.outputKey.rangeMin == -1)
        #expect(posXMapping.outputKey.rangeMax == 1)

        for key in ["_posY", "_posZ"] {
            let mapping = try #require(mappings.first { $0.input.key == key })
            #expect(mapping.outputKey.rangeMin == 0)
            #expect(mapping.outputKey.rangeMax == 0)
        }
    }

    @Test
    func visionHeadPoseEstimatorDelegatesToInjectedImplementation() {
        let mock = MockHeadPoseEstimator()
        let defaultCreate = VisionHeadPoseEstimator.create
        defer {
            VisionHeadPoseEstimator.create = defaultCreate
        }
        VisionHeadPoseEstimator.create = {
            mock
        }

        let estimator = VisionHeadPoseEstimator()

        estimator.configure(size: .init(width: 640, height: 480))
        estimator.calibrate()

        #expect(mock.configuredSize == .init(width: 640, height: 480))
        #expect(mock.isCalibrated)
    }
}

private final class MockHeadPoseEstimator: HeadPoseEstimator {
    var configuredSize: CGSize?
    var isCalibrated = false

    func configure(size: CGSize) {
        configuredSize = size
    }

    func calibrate() {
        isCalibrated = true
    }

    func estimate(_ landmarks: VisionLandmarks, observation: FaceObservation) -> (position: SIMD3<Float>, rotation: SIMD3<Float>) {
        (.zero, .zero)
    }
}
