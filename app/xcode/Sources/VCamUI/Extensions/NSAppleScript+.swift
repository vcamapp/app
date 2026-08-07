import Foundation

extension NSAppleScript {
    @concurrent
    static func execute(_ source: String) async throws {
        guard let script = NSAppleScript(source: source) else {
            throw NSError(domain: "tattn.vcam", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to load this file"])
        }
        try execute(script)
    }

    @concurrent
    static func execute(contentsOf url: URL) async throws {
        var error: NSDictionary?
        guard let script = NSAppleScript(contentsOf: url, error: &error) else {
            throw NSError(error)
        }
        try execute(script)
    }

    private static func execute(_ script: NSAppleScript) throws {
        var error: NSDictionary?
        _ = script.executeAndReturnError(&error).stringValue ?? ""

        if let error {
            throw NSError(error)
        }
    }
}

private extension NSError {
    convenience init(_ error: NSDictionary?) {
        guard let error else {
            self.init(domain: "tattn.vcam", code: 0)
            return
        }

        let message = error[NSAppleScript.errorMessage] as? String ?? ""
        let code = error[NSAppleScript.errorNumber] as? Int ?? 0
        self.init(domain: "tattn.vcam", code: 0, userInfo: [NSLocalizedDescriptionKey: "\(message)(\(code))"])
    }
}
