import Foundation
import simd
import Vision

public typealias FingerTrackingConfiguration = (open: Float, close: Float, isFingerEnabled: Bool)

public struct VCamHands {
    public var left: Hand?  // The left hand of the human side (the right hand of the avatar side)
    public var right: Hand? // The right hand of the human side (the left hand of the avatar side)

    public init(left: Hand?, right: Hand?) {
        self.left = left
        self.right = right
    }

    public struct Hand: Sendable {
        public let wrist: SIMD2<Float>
        public let thumbCMC: SIMD2<Float>
        public let littleMCP: SIMD2<Float>
        public let thumbTip: Float // 1 is the extended state, 0 is the clenched state
        public let indexTip: Float
        public let middleTip: Float
        public let ringTip: Float
        public let littleTip: Float

        public init(wrist: SIMD2<Float>, thumbCMC: SIMD2<Float>, littleMCP: SIMD2<Float>, thumbTip: Float, indexTip: Float, middleTip: Float, ringTip: Float, littleTip: Float) {
            self.wrist = wrist
            self.thumbCMC = thumbCMC
            self.littleMCP = littleMCP
            self.thumbTip = thumbTip
            self.indexTip = indexTip
            self.middleTip = middleTip
            self.ringTip = ringTip
            self.littleTip = littleTip
        }

        // When unable to track, set the grip to a naturally relaxed level
        public static let missing = Hand(wrist: -.one, thumbCMC: -.one, littleMCP: -.one, thumbTip: 0.75, indexTip: 0.75, middleTip: 0.75, ringTip: 0.75, littleTip: 0.75)

        @inline(__always) @inlinable
        public static func finger(_ p: SIMD2<Float>, wrist: SIMD2<Float>, palmHeight: Float, configuration config: FingerTrackingConfiguration) -> Float {
            if p != .zero {
                // Distance between the fingertip and the wrist
                return simd_clamp(simd_distance(p, wrist) * 0.8 * config.open / palmHeight - 0.5 * config.close, 0, 1)
            } else {
                return 0
            }
        }
    }
}

public extension VCamHands {
    init(observations: [VNHumanHandPoseObservation], configuration config: FingerTrackingConfiguration) throws {
        let observations = try observations.filter { (try $0.recognizedPoint(.wrist)).confidence > 0.6 }
        let points = try observations.map { try $0.recognizedPoints(.all) }

        var left, right: Hand?

        if observations.count == 1 {
            switch observations[0].chirality {
            case .unknown:
                // If only one hand is present, determine left or right based on the screen orientation
                let p = points[0]
                if p[.wrist]?.x ?? 0 > 0.5 {
                    left = .init(p: p, isRight: false, configuration: config)
                } else {
                    right = .init(p: p, isRight: true, configuration: config)
                }
            case .left:
                left = .init(p: points[0], isRight: false, configuration: config)
            case .right:
                right = .init(p: points[0], isRight: true, configuration: config)
            }
        } else if observations.allSatisfy({ $0.chirality == .unknown }) {
            if let rightPoints = points.max(by: { $0[.wrist]?.x ?? 0 > $1[.wrist]?.x ?? 0 }) {
                right = .init(p: rightPoints, isRight: true, configuration: config)
            }
            if let leftPoints = points.max(by: { $0[.wrist]?.x ?? 0 <= $1[.wrist]?.x ?? 0 }) {
                left = .init(p: leftPoints, isRight: false, configuration: config)
            }
        } else {
            if let index = observations.firstIndex(where: { $0.chirality == .left }) {
                left = .init(p: points[index], isRight: false, configuration: config)
            }
            if let index = observations.firstIndex(where: { $0.chirality == .right }) {
                right = .init(p: points[index], isRight: true, configuration: config)
            }
            if let index = observations.firstIndex(where: { $0.chirality == .unknown }) {
                if right == nil {
                    right = .init(p: points[index], isRight: true, configuration: config)
                }
                if left == nil {
                    left = .init(p: points[index], isRight: false, configuration: config)
                }
            }
        }

        self.init(left: left, right: right)
    }

    func vcamHandFingerTransform() -> (hand: [Float], finger: [Float]) {
        let left = self.left ?? .missing
        let right = self.right ?? .missing
        return (
            [
                left.wrist.x,       // 0
                left.wrist.y,       // 1
                right.wrist.x,      // 2
                right.wrist.y,      // 3
                left.thumbCMC.x,    // 4
                left.thumbCMC.y,    // 5
                right.thumbCMC.x,   // 6
                right.thumbCMC.y,   // 7
                left.littleMCP.x,   // 8
                left.littleMCP.y,   // 9
                right.littleMCP.x,  // 10
                right.littleMCP.y,  // 11
            ],
            [
                left.thumbTip,      // 0
                left.indexTip,      // 1
                left.middleTip,     // 2
                left.ringTip,       // 3
                left.littleTip,     // 4
                right.thumbTip,     // 5
                right.indexTip,     // 6
                right.middleTip,    // 7
                right.ringTip,      // 8
                right.littleTip,    // 9
            ]
        )
    }
}

public extension VCamHands.Hand {
    init?(p: [VNHumanHandPoseObservation.JointName : VNRecognizedPoint], isRight: Bool, configuration config: FingerTrackingConfiguration) {
        guard let wrist = p[.wrist], let thumbCMC = p[.thumbCMC], let littleMCP = p[.littleMCP] else {
            return nil
        }

        self.init(
            hand: .init(
                wrist: wrist.vector,
                thumbCMC: thumbCMC.vector,
                littleMCP: littleMCP.vector,
                thumbTip: p[.thumbTip]?.vector ?? .zero,
                indexTip: p[.indexTip]?.vector ?? .zero,
                middleTip: p[.middleTip]?.vector ?? .zero,
                ringTip: p[.ringTip]?.vector ?? .zero,
                littleTip: p[.littleTip]?.vector ?? .zero
            ),
            isRight: isRight,
            configuration: config
        )
    }

    init?(hand: VCamMotion.Hand, isRight: Bool, configuration config: FingerTrackingConfiguration) {
        guard !hand.isInvalid else {
            return nil
        }
        
        // Originally, the origin is the bottom right, with the top left being positive (opposite of a mirror)
        // Convert to a coordinate system where the center of the body is the origin and left-right is the positive direction (0.0 to 1.0)
        let wrist: SIMD2<Float>, thumbCMC: SIMD2<Float>, littleMCP: SIMD2<Float>
        if isRight {
            wrist = SIMD2(x: 1 - hand.wrist.x * 2, y: hand.wrist.y)
            thumbCMC = SIMD2(x: 1 - hand.thumbCMC.x * 2, y: hand.thumbCMC.y)
            littleMCP = SIMD2(x: 1 - hand.littleMCP.x * 2, y: hand.littleMCP.y)
        } else {
            wrist = SIMD2(x: hand.wrist.x * 2 - 1, y: hand.wrist.y)
            thumbCMC = SIMD2(x: hand.thumbCMC.x * 2 - 1, y: hand.thumbCMC.y)
            littleMCP = SIMD2(x: hand.littleMCP.x * 2 - 1, y: hand.littleMCP.y)
        }

        guard config.isFingerEnabled else {
            self.init(wrist: wrist, thumbCMC: thumbCMC, littleMCP: littleMCP, thumbTip: 0.7, indexTip: 0.7, middleTip: 0.7, ringTip: 0.7, littleTip: 0.7)
            return
        }

        let palmWidth = simd_distance(hand.thumbCMC, hand.littleMCP)
        let palmHeight = simd_distance(hand.littleMCP, hand.wrist)
        let thumbTip: Float

        if hand.thumbTip != .zero {
            // Distance between the base of the pinky and the tip of the thumb (*2 and -1 are used to make it easier to close and open)
            thumbTip = simd_clamp(simd_distance(hand.thumbTip, hand.littleMCP) * 2 * config.open / palmWidth - 1 * config.close, 0, 1)
        } else {
            thumbTip = 0 // If the thumb is not visible, consider it as a clenched state
        }

        let indexTip = Self.finger(hand.indexTip, wrist: hand.wrist, palmHeight: palmHeight, configuration: config)
        let middleTip = Self.finger(hand.middleTip, wrist: hand.wrist, palmHeight: palmHeight, configuration: config)
        let ringTip = Self.finger(hand.ringTip, wrist: hand.wrist, palmHeight: palmHeight, configuration: config)
        let littleTip = Self.finger(hand.littleTip, wrist: hand.wrist, palmHeight: palmHeight, configuration: config)

        self.init(wrist: wrist, thumbCMC: thumbCMC, littleMCP: littleMCP, thumbTip: thumbTip, indexTip: indexTip, middleTip: middleTip, ringTip: ringTip, littleTip: littleTip)
    }
}

private extension VNRecognizedPoint {
    var vector: SIMD2<Float> {
        .init(Float(x), Float(y))
    }
}
