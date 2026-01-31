//
//  NSAppleScript+.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/17.
//

import Foundation

extension NSAppleScript {
    @concurrent
    static func execute(_ source: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                guard let script = NSAppleScript(source: source) else {
                    continuation.resume(throwing: NSError(domain: "tattn.vcam", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to load this file"]))
                    return
                }

                do {
                    try execute(script)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @concurrent
    static func execute(contentsOf url: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                var error: NSDictionary?
                guard let script = NSAppleScript(contentsOf: url, error: &error) else {
                    continuation.resume(throwing: NSError(error))
                    return
                }

                do {
                    try execute(script)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
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
