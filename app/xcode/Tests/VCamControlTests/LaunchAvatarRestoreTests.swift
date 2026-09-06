import Foundation
import Testing
@testable import VCamControl

@MainActor
@Suite(.serialized)
struct LaunchAvatarRestoreTests {
    private final class Recorder {
        var restored: [String] = []
        var handedOver: [String] = []
    }

    private func register(_ name: String, pending: Bool, recorder: Recorder, engineFile: URL? = nil) {
        var takeModelFileForEngine: (@MainActor () -> URL?)?
        if let engineFile {
            takeModelFileForEngine = {
                recorder.handedOver.append(name)
                return engineFile
            }
        }
        LaunchAvatarRestore.register(.init(
            hasPendingRestore: { pending },
            restore: { recorder.restored.append(name) },
            takeModelFileForEngine: takeModelFileForEngine
        ))
    }

    @Test
    func engineTakesFileFromFirstPendingSourceAndBridgeRestoreIsSkipped() {
        LaunchAvatarRestore.reset()
        let recorder = Recorder()
        let file = URL(filePath: "/tmp/model.vrm")
        register("skipped", pending: false, recorder: recorder, engineFile: URL(filePath: "/tmp/other.vrm"))
        register("file", pending: true, recorder: recorder, engineFile: file)

        #expect(LaunchAvatarRestore.takeModelFileForEngine() == file)
        #expect(LaunchAvatarRestore.takeModelFileForEngine() == nil)
        LaunchAvatarRestore.restoreOnLaunch()

        #expect(recorder.handedOver == ["file"])
        #expect(recorder.restored.isEmpty)
    }

    @Test
    func sourceWithoutFileKeepsBridgeRestore() {
        LaunchAvatarRestore.reset()
        let recorder = Recorder()
        register("network", pending: true, recorder: recorder)
        register("file", pending: true, recorder: recorder, engineFile: URL(filePath: "/tmp/model.vrm"))

        #expect(LaunchAvatarRestore.takeModelFileForEngine() == nil)
        LaunchAvatarRestore.restoreOnLaunch()
        LaunchAvatarRestore.restoreOnLaunch()

        #expect(recorder.handedOver.isEmpty)
        #expect(recorder.restored == ["network"])
    }

    @Test
    func nothingPendingHandsOverNothing() {
        LaunchAvatarRestore.reset()
        let recorder = Recorder()
        register("file", pending: false, recorder: recorder, engineFile: URL(filePath: "/tmp/model.vrm"))

        #expect(LaunchAvatarRestore.hasPendingRestore == false)
        #expect(LaunchAvatarRestore.takeModelFileForEngine() == nil)
        LaunchAvatarRestore.restoreOnLaunch()

        #expect(recorder.handedOver.isEmpty)
        #expect(recorder.restored.isEmpty)
    }
}
