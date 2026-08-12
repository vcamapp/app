import Foundation
import Testing
import VCamEntity
import VCamData
@testable import VCamBridge
import VCamControl

@MainActor
@Suite
struct MotionControlTests {
    private enum Call: Equatable {
        case play(id: String, isLoop: Bool)
        case stop(id: String)
    }

    private static let builtInMotionID = MotionID.builtIn(name: "hi").rawValue

    private static let library: MotionLibrary = {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "MotionControlTests")
            .appending(path: UUID().uuidString)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return MotionLibrary(store: ImportedMotionStore(
            manifestURL: directory.appending(path: "manifest.json"),
            filesDirectory: directory.appending(path: "files")
        ))
    }()

    private func recordedCalls(during body: () -> Void) -> [Call] {
        recordedMethodCalls({ method, payload in
            if method == .playMotion {
                let payload = payload!.load(as: PlayMotionPayload.self)
                return .play(id: String(cString: payload.stringPtr!), isLoop: payload.isLoop == 1)
            } else if method == .stopMotion {
                return .stop(id: String(cString: payload!.assumingMemoryBound(to: CChar.self)))
            }
            return nil
        }, during: body)
    }

    @Test
    func togglePlaysStoppedMotionWithShortcutLoopDefault() {
        let calls = recordedCalls {
            MotionControl.toggle(id: Self.builtInMotionID, trigger: .shortcut, library: Self.library, state: UniState())
        }
        #expect(calls == [.play(id: Self.builtInMotionID, isLoop: true)])
    }

    @Test
    func togglePlaysStoppedMotionWithoutLoopFromToolbar() {
        let calls = recordedCalls {
            MotionControl.toggle(id: Self.builtInMotionID, trigger: .toolbar, library: Self.library, state: UniState())
        }
        #expect(calls == [.play(id: Self.builtInMotionID, isLoop: false)])
    }

    @Test
    func toggleStopsPlayingMotion() {
        let state = UniState()
        state.isMotionPlaying[Self.builtInMotionID] = true
        let calls = recordedCalls {
            MotionControl.toggle(id: Self.builtInMotionID, trigger: .shortcut, library: Self.library, state: state)
        }
        #expect(calls == [.stop(id: Self.builtInMotionID)])
    }

    @Test
    func toggleIgnoresUnknownMotions() {
        let calls = recordedCalls {
            MotionControl.toggle(id: MotionID.imported(id: UUID()).rawValue, trigger: .shortcut, library: Self.library, state: UniState())
            MotionControl.toggle(id: "invalid", trigger: .shortcut, library: Self.library, state: UniState())
        }
        #expect(calls.isEmpty)
    }
}
