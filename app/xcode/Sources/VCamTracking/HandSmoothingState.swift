struct HandSmoothingState {
    private var prevHands = Array(repeating: RevisedMovingAverage<SIMD2<Float>>(weight: .six), count: 6)
    private var prevFingers = Array(repeating: RevisedMovingAverage<Float>(weight: .six), count: 10)

    mutating func makeOutput(
        hands: VCamHands,
        needsHandOutput: Bool,
        needsFingerOutput: Bool
    ) -> HandTrackingOutput {
        let left = hands.left ?? .missing
        let right = hands.right ?? .missing

        var handsValues: [Float]?
        var fingersValues: [Float]?

        if needsHandOutput {
            resetMissingHandStateIfNeeded(hands)

            let wristLeft = prevHands[0].appending(left.wrist)
            let wristRight = prevHands[1].appending(right.wrist)
            let thumbCMCLeft = prevHands[2].appending(left.thumbCMC)
            let thumbCMCRight = prevHands[3].appending(right.thumbCMC)
            let littleMCPLeft = prevHands[4].appending(left.littleMCP)
            let littleMCPRight = prevHands[5].appending(right.littleMCP)

            handsValues = [
                wristLeft.x, wristLeft.y,
                wristRight.x, wristRight.y,
                thumbCMCLeft.x, thumbCMCLeft.y,
                thumbCMCRight.x, thumbCMCRight.y,
                littleMCPLeft.x, littleMCPLeft.y,
                littleMCPRight.x, littleMCPRight.y,
            ]
        }

        if needsFingerOutput {
            fingersValues = [
                prevFingers[0].appending(left.thumbTip),
                prevFingers[1].appending(left.indexTip),
                prevFingers[2].appending(left.middleTip),
                prevFingers[3].appending(left.ringTip),
                prevFingers[4].appending(left.littleTip),
                prevFingers[5].appending(right.thumbTip),
                prevFingers[6].appending(right.indexTip),
                prevFingers[7].appending(right.middleTip),
                prevFingers[8].appending(right.ringTip),
                prevFingers[9].appending(right.littleTip),
            ]
        }

        return HandTrackingOutput(handsValues: handsValues, fingersValues: fingersValues)
    }

    private mutating func resetMissingHandStateIfNeeded(_ hands: VCamHands) {
        let left = hands.left ?? .missing
        let right = hands.right ?? .missing

        if hands.left == nil {
            prevHands[0].setValues(-.one)
            prevHands[2].setValues(-.one)
            prevHands[4].setValues(-.one)
        } else if prevHands[0].latestValue.x == -1 {
            prevHands[0].setValues(left.wrist)
            prevHands[2].setValues(left.thumbCMC)
            prevHands[4].setValues(left.littleMCP)
        }

        if hands.right == nil {
            prevHands[1].setValues(-.one)
            prevHands[3].setValues(-.one)
            prevHands[5].setValues(-.one)
        } else if prevHands[1].latestValue.x == -1 {
            prevHands[1].setValues(right.wrist)
            prevHands[3].setValues(right.thumbCMC)
            prevHands[5].setValues(right.littleMCP)
        }
    }
}
