import Foundation
import AppKit
import SystemExtensions

public final class CameraExtension: NSObject {
    public override init() {
        super.init()
    }

    private static let identifier = "com.github.tattn.VCam.CameraExtension"

    /// sysextd rejects activation unless the host app is under /Applications; translocated copies also fail this requirement
    public static var isAppInApplicationsFolder: Bool {
#if DEBUG
        true // Debug builds run from the build directory with developer mode (systemextensionsctl developer on), which lifts the location requirement
#else
        Bundle.main.bundleURL.path.hasPrefix("/Applications/")
#endif
    }

    private var activationRequestContinuation: CheckedContinuation<OSSystemExtensionRequest.Result, any Error>?
    private var deactivationRequestContinuation: CheckedContinuation<Void, any Error>?
    private var propertiesRequestContinuation: CheckedContinuation<OSSystemExtensionProperties, any Error>?

    @discardableResult
    @concurrent
    public func installExtension() async throws -> OSSystemExtensionRequest.Result {
        return try await withCheckedThrowingContinuation { continuation in
            self.activationRequestContinuation = continuation
            let activationRequest = OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: Self.identifier, queue: .main)
            activationRequest.delegate = self
            OSSystemExtensionManager.shared.submitRequest(activationRequest)
        }
    }

    @concurrent
    public func uninstallExtension() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            self.deactivationRequestContinuation = continuation
            let deactivationRequest = OSSystemExtensionRequest.deactivationRequest(forExtensionWithIdentifier: Self.identifier, queue: .main)
            deactivationRequest.delegate = self
            OSSystemExtensionManager.shared.submitRequest(deactivationRequest)
        }
    }

    @concurrent
    public func extensionProperties() async throws -> OSSystemExtensionProperties {
        return try await withCheckedThrowingContinuation { continuation in
            self.propertiesRequestContinuation = continuation
            let propertiesRequest = OSSystemExtensionRequest.propertiesRequest(forExtensionWithIdentifier: Self.identifier, queue: .main)
            propertiesRequest.delegate = self
            OSSystemExtensionManager.shared.submitRequest(propertiesRequest)
        }
    }

    public struct Status: Sendable {
        public let isInstalled: Bool
        public let isAwaitingUserApproval: Bool
    }

    /// Returns the extension status; a failed properties request reads as not installed
    @concurrent
    public func status() async -> Status {
        guard let properties = try? await extensionProperties() else {
            return Status(isInstalled: false, isAwaitingUserApproval: false)
        }
        return Status(isInstalled: !properties.isUninstalling, isAwaitingUserApproval: properties.isAwaitingUserApproval)
    }

    @concurrent
    public func isInstalled() async -> Bool {
        await status().isInstalled
    }

    @concurrent
    public func installExtensionIfNotInstalled() async throws {
        if await isInstalled() {
            return
        }
        try await installExtension()
    }

}

extension CameraExtension: OSSystemExtensionRequestDelegate {
    public func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        activationRequestContinuation?.resume(returning: result)
        activationRequestContinuation = nil
        deactivationRequestContinuation?.resume()
        deactivationRequestContinuation = nil
    }

    public func request(_ request: OSSystemExtensionRequest, didFailWithError error: any Error) {
        activationRequestContinuation?.resume(throwing: error)
        activationRequestContinuation = nil
        deactivationRequestContinuation?.resume(throwing: error)
        deactivationRequestContinuation = nil
    }

    public func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {

    }

    public func request(_ request: OSSystemExtensionRequest, foundProperties properties: [OSSystemExtensionProperties]) {
        guard let continuation = propertiesRequestContinuation else { return }
        propertiesRequestContinuation = nil
        if let property = properties.first {
            continuation.resume(returning: property)
        } else {
            continuation.resume(throwing: NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to get the properties"]))
        }
    }

    public func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties, withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        .replace
    }
}

extension OSSystemExtensionProperties: @retroactive @unchecked Sendable {}
