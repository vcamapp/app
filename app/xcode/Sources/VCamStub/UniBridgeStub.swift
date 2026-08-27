import AppKit
import VCamBridge

@MainActor
public final class UniBridgeStub {
    public static let shared = UniBridgeStub()

    private var boolTypes: [UniBridge.BoolType: Bool] = [.hasPerfectSyncBlendShape: true, .useAddToMacOSMenuBar: true]
    private var intTypes: [UniBridge.IntType: Int32] = [:]
    private var floatTypes: [UniBridge.FloatType: CGFloat] = [:]
    private var stringTypes: [UniBridge.StringType: String] = [:]
    private var arrayTypes: [UniBridge.ArrayType: UnsafeMutableRawPointer] = [:]

    private var emptyArray: [Float] = []
    private lazy var emptyArrayPointer = UnsafeMutableRawPointer(emptyArray.withUnsafeMutableBufferPointer { $0.baseAddress! })

    public func stub(_ action: UniBridge) {
        action.stringMapper.getValue = { type in self.stringTypes[type] ?? "" }
        action.stringMapper.setValue = { type, value in self.stringTypes[type] = value }
        action.floatMapper.getValue = { type in self.floatTypes[type] ?? 0 }
        action.floatMapper.setValue = { type, value in self.floatTypes[type] = value }
        action.boolMapper.getValue = { type in self.boolTypes[type] ?? false }
        action.boolMapper.setValue = { type, value in self.boolTypes[type] = value }
        action.intMapper.getValue = { type in return self.intTypes[type] ?? 0 }
        action.intMapper.setValue = { type, value in self.intTypes[type] = value }
        action.arrayMapper.getValue = { type in return self.arrayTypes[type] ?? self.emptyArrayPointer }
        action.arrayMapper.setValue = { type, value in self.arrayTypes[type] = value }
        action.triggerMapper.getValue = { type in
            // Quitting normally goes through the engine; without it the app has to terminate itself
            if type == .quitApp {
                NSApp.terminate(nil)
            }
        }
        // The engine is what resumes a waiting caller, so the stub answers every
        // request as it is sent; a call that waits for nothing is a no-op
        UniBridge.methodCallback = { method, payload, _ in
            MainActor.assumeIsolated {
                UniBridge.completeRequest(method: method, payload: payload, errorCode: 0)
            }
        }
    }
}
