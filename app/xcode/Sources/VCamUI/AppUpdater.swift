import Foundation
import VCamEntity
import AppKit

public struct AppUpdater: Sendable {
    public init(repository: AppUpdater.Repository) {
        self.repository = repository
    }

    let repository: Repository

    @concurrent
    func check() async throws -> LatestRelease? {
        let (data, _) = try await URLSession.shared.data(from: repository.releasesURL)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let releases = try decoder.decode([Release].self, from: data)
        let latestRelease = try LatestRelease(releases: releases)

#if DEBUG
        return latestRelease
#else
        return Version.current < latestRelease.version ? latestRelease : nil
#endif
    }

    public struct Repository: Sendable {
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
        let downloadURL: URL

        fileprivate init(releases: [Release]) throws {
            guard let (release, dmgURL) = releases.lazy
                .filter({ !$0.prerelease })
                .compactMap({ release in release.dmgURL.map { (release, $0) } })
                .first else {
                throw Error.noRelease
            }
            version = release.tagName
            body = release.body
            downloadURL = dmgURL
        }
    }

    public enum Error: Swift.Error {
        case noRelease
    }

    fileprivate struct Release: Decodable {
        let tagName: Version
        let prerelease: Bool
        let assets: [Asset]
        let body: String

        var dmgURL: URL? {
            assets.first { $0.browserDownloadUrl.pathExtension == "dmg" }?.browserDownloadUrl
        }

        struct Asset: Decodable {
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
