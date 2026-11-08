import Testing
import VCamControl

@MainActor
@Suite
struct ControlAnimationTests {
    @Test(arguments: [AnimationEasing.linear, .easeIn, .easeOut, .easeInOut])
    func easingsStartAndEndInPlace(easing: AnimationEasing) {
        #expect(easing.progress(0) == 0)
        #expect(easing.progress(1) == 1)
    }

    @Test(arguments: [AnimationEasing.linear, .easeIn, .easeOut, .easeInOut])
    func easingsNeverMoveBackward(easing: AnimationEasing) {
        let values = (0...100).map { easing.progress(Double($0) / 100) }

        #expect(zip(values, values.dropFirst()).allSatisfy { $0 <= $1 })
    }

    @Test
    func easingsShapeTheMiddleOfTheMove() {
        #expect(AnimationEasing.easeIn.progress(0.5) < 0.5)
        #expect(AnimationEasing.easeOut.progress(0.5) > 0.5)
        #expect(AnimationEasing.easeInOut.progress(0.5) == 0.5)
        #expect(AnimationEasing.easeInOut.progress(0.25) < 0.25)
    }

    @Test
    func anAnimationEndsAtTheTarget() async {
        let slot = AnimationSlot()
        var progresses: [Double] = []

        let finished = await slot.run(.init(duration: 0.05, easing: .linear)) { progresses.append($0) }

        #expect(finished)
        #expect(progresses.last == 1)
        #expect(progresses.count > 1)
        #expect(zip(progresses, progresses.dropFirst()).allSatisfy { $0 <= $1 })
    }

    @Test
    func aNewAnimationTakesOver() async {
        let slot = AnimationSlot()
        var firstProgresses: [Double] = []
        let first = Task { @MainActor in
            await slot.run(.init(duration: 10, easing: .linear)) { firstProgresses.append($0) }
        }
        try? await Task.sleep(for: .milliseconds(40))

        let secondFinished = await slot.run(.init(duration: 0.02, easing: .linear)) { _ in }

        #expect(await first.value == false)
        #expect(secondFinished)
        #expect(firstProgresses.last != 1)
    }
}
