//
//  LicenseManager.swift
//
//
//  Created by tattn on 2025/11/20.
//

import Foundation
import VCamEntity
import SwiftUI

public protocol LicenseManager: Observable {
    var licenseState: LicenseState { get }
    var expiryDate: Date? { get }
    var licenseURL: URL { get }
    func signIn()
    func signOut() throws
    func openManagementPage()
    func updateStatus() async
}

public struct LicenseManagerStub: LicenseManager {
    public var licenseState: LicenseState
    public var expiryDate: Date?
    public var licenseURL = URL(string: "https://vcamapp.com")!

    public init(
        licenseState: LicenseState = .loading,
        expiryDate: Date? = nil
    ) {
        self.licenseState = licenseState
        self.expiryDate = expiryDate
    }

    public func signIn() {}
    public func signOut() throws {}
    public func openManagementPage() {}
    public func updateStatus() async {}
}

public extension EnvironmentValues {
    @Entry var licenseManager: any LicenseManager = LicenseManagerStub()
}
