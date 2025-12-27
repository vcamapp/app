//
//  CameraExtension.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/02/16.
//

import Foundation
import AppKit
import SystemExtensions

public final class CameraExtension: NSObject {
    public override init() {
        super.init()
    }

    private let identifier = "com.github.tattn.VCam.CameraExtension"

    private var activationRequestContinuation: CheckedContinuation<Void, any Error>?
    private var deactivationRequestContinuation: CheckedContinuation<Void, any Error>?
    private var propertiesRequestContinuation: CheckedContinuation<OSSystemExtensionProperties, any Error>?

    public func installExtension() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            self.activationRequestContinuation = continuation
            let activationRequest = OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: identifier, queue: .main)
            activationRequest.delegate = self
            OSSystemExtensionManager.shared.submitRequest(activationRequest)
        }
    }

    public func uninstallExtension() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            self.deactivationRequestContinuation = continuation
            let deactivationRequest = OSSystemExtensionRequest.deactivationRequest(forExtensionWithIdentifier: identifier, queue: .main)
            deactivationRequest.delegate = self
            OSSystemExtensionManager.shared.submitRequest(deactivationRequest)
        }
    }

    public func extensionProperties() async throws -> OSSystemExtensionProperties {
        return try await withCheckedThrowingContinuation { continuation in
            self.propertiesRequestContinuation = continuation
            let propertiesRequest = OSSystemExtensionRequest.propertiesRequest(forExtensionWithIdentifier: identifier, queue: .main)
            propertiesRequest.delegate = self
            OSSystemExtensionManager.shared.submitRequest(propertiesRequest)
        }
    }

    public func installExtensionIfNotInstalled() async throws {
        if CoreMediaSinkStream.isInstalled {
            return
        }
        try await installExtension()
    }
}

extension CameraExtension: OSSystemExtensionRequestDelegate {
    public func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        if let continuation = activationRequestContinuation ?? deactivationRequestContinuation {
            continuation.resume()
            activationRequestContinuation = nil
            deactivationRequestContinuation = nil
        }
    }

    public func request(_ request: OSSystemExtensionRequest, didFailWithError error: any Error) {
        if let continuation = activationRequestContinuation ?? deactivationRequestContinuation {
            continuation.resume(throwing: error)
            activationRequestContinuation = nil
            deactivationRequestContinuation = nil
        }
    }

    public func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {

    }

    public func request(_ request: OSSystemExtensionRequest, foundProperties properties: [OSSystemExtensionProperties]) {
        guard let continuation = propertiesRequestContinuation else { return }
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
