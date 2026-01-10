//
//  AppUpdater.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/04/23.
//

import Foundation
import VCamEntity
import AppKit

public struct AppUpdater {
    public init(repository: AppUpdater.Repository) {
        self.repository = repository
    }

    let repository: Repository

    public func check() async throws -> LatestRelease? {
        guard Bundle.main.executableURL != nil else {
            throw Error.invalidExecutableURL
        }

        let (data, _) = try await URLSession.shared.data(from: repository.releasesURL)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let releases = try decoder.decode([Release].self, from: data)
        let latestRelease = try LatestRelease(releases: releases)

#if DEBUG
        return latestRelease
#else
        if Version.current < latestRelease.version {
            return latestRelease
        } else {
            return nil
        }
#endif
    }

    public struct Repository {
        public init(owner: String, repo: String) {
            self.owner = owner
            self.repo = repo
        }

        let owner: String
        let repo: String

        var slug: String {
            "\(owner)/\(repo)"
        }

        var releasesURL: URL {
            URL(string: "https://api.github.com/repos/\(slug)/releases")!
        }
    }

    public struct LatestRelease {
        let version: Version
        let body: String
        let assetName: String
        let htmlUrl: URL
        let downloadURL: URL

        fileprivate init(releases: [Release]) throws {
            guard let release = releases.first(where: { $0.dmgURL != nil }) else {
                throw Error.noRelease
            }
            version = release.tagName
            body = release.body
            assetName = release.assets[0].name
            htmlUrl = release.htmlUrl
            downloadURL = release.assets[0].browserDownloadUrl
        }
    }

    public enum Error: Swift.Error {
        case invalidExecutableURL
        case noRelease
    }

    fileprivate struct Release: Decodable {
        let htmlUrl: URL
        let tagName: Version
        let prerelease: Bool
        let assets: [Asset]
        let body: String

        var dmgURL: URL? {
            assets.first { $0.browserDownloadUrl.pathExtension == "dmg" }?.browserDownloadUrl
        }

        struct Asset: Decodable {
            let name: String
            let browserDownloadUrl: URL
        }
    }
}

extension AppUpdater {
#if FEATURE_3
    public static var vcam: AppUpdater {
        AppUpdater(repository: .init(owner: "vcamapp", repo: "app"))
    }
#else
    public static var vcam: AppUpdater {
        AppUpdater(repository: .init(owner: "vcamapp", repo: "app2d"))
    }
#endif
}
