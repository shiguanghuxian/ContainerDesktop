import CryptoKit
import Foundation

enum AppUpdateServiceError: LocalizedError, Hashable {
    case invalidHTTPStatus(Int, String)
    case invalidManifest
    case invalidReleaseVersion(String)
    case missingCompatibleAsset(AppUpdateArchitecture)
    case missingChecksum(String)
    case checksumMismatch(expected: String, actual: String)

    var errorDescription: String? {
        switch self {
        case .invalidHTTPStatus(let statusCode, let detail):
            let suffix = detail.trimmed.isEmpty ? "" : " \(detail)"
            return "Update server returned HTTP \(statusCode).\(suffix)"
        case .invalidManifest:
            return "The update manifest is invalid."
        case .invalidReleaseVersion(let version):
            return "The update version `\(version)` could not be parsed."
        case .missingCompatibleAsset(let architecture):
            return "No macOS \(architecture.rawValue) update package was found."
        case .missingChecksum(let name):
            return "The update package `\(name)` does not include a SHA256 checksum."
        case .checksumMismatch(let expected, let actual):
            return "The update package checksum did not match. Expected \(expected), got \(actual)."
        }
    }
}

struct AppUpdateCachedResponse: Codable, Hashable, Sendable {
    var url: URL
    var eTag: String?
    var lastModified: String?
    var responseData: Data
    var updatedAt: Date
}

final class AppUpdateResponseCacheStore: @unchecked Sendable {
    private let directory: URL
    private let fileManager: FileManager

    init(
        directory: URL = AppPaths.appUpdateCacheDirectory,
        fileManager: FileManager = .default
    ) {
        self.directory = directory
        self.fileManager = fileManager
    }

    func load(key: String, url: URL) -> AppUpdateCachedResponse? {
        let fileURL = fileURL(for: key)
        guard let data = try? Data(contentsOf: fileURL),
              let cached = try? JSONDecoder().decode(AppUpdateCachedResponse.self, from: data),
              cached.url == url,
              !cached.responseData.isEmpty
        else {
            return nil
        }
        return cached
    }

    func save(key: String, url: URL, response: HTTPURLResponse, data: Data) {
        guard !data.isEmpty else { return }
        let cached = AppUpdateCachedResponse(
            url: url,
            eTag: Self.header("ETag", response: response),
            lastModified: Self.header("Last-Modified", response: response),
            responseData: data,
            updatedAt: Date()
        )
        guard let encoded = try? JSONEncoder().encode(cached) else { return }
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try encoded.write(to: fileURL(for: key), options: .atomic)
        } catch {
        }
    }

    func clear(key: String) {
        try? fileManager.removeItem(at: fileURL(for: key))
    }

    private func fileURL(for key: String) -> URL {
        directory.appendingPathComponent(Self.safeKey(key) + ".json")
    }

    private static func safeKey(_ key: String) -> String {
        String(key.map { character in
            character.isLetter || character.isNumber || character == "-" || character == "_" ? character : "-"
        })
    }

    static func header(_ name: String, response: HTTPURLResponse?) -> String? {
        guard let allHeaderFields = response?.allHeaderFields else { return nil }
        for (key, value) in allHeaderFields {
            guard String(describing: key).caseInsensitiveCompare(name) == .orderedSame else { continue }
            let string = String(describing: value).trimmed
            return string.isEmpty ? nil : string
        }
        return nil
    }
}

protocol AppUpdateServicing: Sendable {
    func checkForUpdate(currentVersion: String, architecture: AppUpdateArchitecture) async throws -> AppUpdateCheckResult
    func download(package: AppUpdatePackage, progress: (@Sendable (Double?) -> Void)?) async throws -> AppUpdateDownloadedPackage
}

struct AppUpdateService: AppUpdateServicing, @unchecked Sendable {
    static let defaultManifestURL = URL(string: "https://github.com/shiguanghuxian/ContainerDesktop/releases/latest/download/appcast.json")!

    private let manifestURL: URL
    private let session: URLSession
    private let fileManager: FileManager
    private let temporaryDirectory: URL
    private let cacheStore: AppUpdateResponseCacheStore

    init(
        manifestURL: URL = Self.defaultManifestURL,
        session: URLSession = URLSession(configuration: .ephemeral),
        fileManager: FileManager = .default,
        temporaryDirectory: URL = FileManager.default.temporaryDirectory,
        cacheStore: AppUpdateResponseCacheStore = AppUpdateResponseCacheStore()
    ) {
        self.manifestURL = manifestURL
        self.session = session
        self.fileManager = fileManager
        self.temporaryDirectory = temporaryDirectory
        self.cacheStore = cacheStore
    }

    func checkForUpdate(
        currentVersion: String = AppUpdateRuntime.releaseVersion,
        architecture: AppUpdateArchitecture = .current
    ) async throws -> AppUpdateCheckResult {
        let release = try await fetchLatestRelease()
        guard let current = SemanticVersion(currentVersion) else {
            throw AppUpdateServiceError.invalidReleaseVersion(currentVersion)
        }
        guard release.version > current else {
            return .upToDate(release)
        }
        guard let asset = release.compatibleAsset(for: architecture) else {
            throw AppUpdateServiceError.missingCompatibleAsset(architecture)
        }
        return .updateAvailable(AppUpdatePackage(release: release, asset: asset))
    }

    func fetchLatestRelease() async throws -> AppUpdateRelease {
        let cacheKey = "appcast"
        let cached = cacheStore.load(key: cacheKey, url: manifestURL)
        var request = URLRequest(url: manifestURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("\(AppUpdateRuntime.appName)/\(AppUpdateRuntime.releaseVersion)", forHTTPHeaderField: "User-Agent")
        if let eTag = cached?.eTag {
            request.setValue(eTag, forHTTPHeaderField: "If-None-Match")
        } else if let lastModified = cached?.lastModified {
            request.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppUpdateServiceError.invalidHTTPStatus(-1, "")
        }
        if httpResponse.statusCode == 304 {
            guard let cached else {
                cacheStore.clear(key: cacheKey)
                return try await fetchLatestReleaseWithoutCache(cacheKey: cacheKey)
            }
            return try AppUpdateManifest.decodeRelease(from: cached.responseData)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AppUpdateServiceError.invalidHTTPStatus(httpResponse.statusCode, Self.responseMessage(from: data))
        }

        let release = try AppUpdateManifest.decodeRelease(from: data)
        cacheStore.save(key: cacheKey, url: manifestURL, response: httpResponse, data: data)
        return release
    }

    private func fetchLatestReleaseWithoutCache(cacheKey: String) async throws -> AppUpdateRelease {
        var request = URLRequest(url: manifestURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("\(AppUpdateRuntime.appName)/\(AppUpdateRuntime.releaseVersion)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppUpdateServiceError.invalidHTTPStatus(-1, "")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AppUpdateServiceError.invalidHTTPStatus(httpResponse.statusCode, Self.responseMessage(from: data))
        }
        let release = try AppUpdateManifest.decodeRelease(from: data)
        cacheStore.save(key: cacheKey, url: manifestURL, response: httpResponse, data: data)
        return release
    }

    func download(
        package: AppUpdatePackage,
        progress: (@Sendable (Double?) -> Void)? = nil
    ) async throws -> AppUpdateDownloadedPackage {
        let workDirectory = temporaryDirectory
            .appendingPathComponent("containerdesktop-update-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        let destinationURL = workDirectory.appendingPathComponent(package.asset.name)

        var request = URLRequest(url: package.asset.downloadURL)
        request.httpMethod = "GET"
        request.setValue("\(AppUpdateRuntime.appName)/\(AppUpdateRuntime.releaseVersion)", forHTTPHeaderField: "User-Agent")

        progress?(nil)
        let (downloadedURL, response) = try await session.download(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppUpdateServiceError.invalidHTTPStatus(-1, "")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let data = (try? Data(contentsOf: downloadedURL)) ?? Data()
            throw AppUpdateServiceError.invalidHTTPStatus(httpResponse.statusCode, Self.responseMessage(from: data))
        }

        try? fileManager.removeItem(at: destinationURL)
        try fileManager.moveItem(at: downloadedURL, to: destinationURL)
        try verifyChecksum(for: destinationURL, asset: package.asset)
        progress?(1.0)
        return AppUpdateDownloadedPackage(package: package, fileURL: destinationURL)
    }

    func verifyChecksum(for fileURL: URL, asset: AppUpdateAsset) throws {
        let expected = asset.normalizedSHA256
        guard !expected.isEmpty else {
            throw AppUpdateServiceError.missingChecksum(asset.name)
        }
        let actual = try Self.sha256HexDigest(for: fileURL)
        guard expected == actual else {
            try? fileManager.removeItem(at: fileURL)
            throw AppUpdateServiceError.checksumMismatch(expected: expected, actual: actual)
        }
    }

    static func sha256HexDigest(for fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            let chunk = try handle.read(upToCount: 1024 * 1024) ?? Data()
            guard !chunk.isEmpty else { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func responseMessage(from data: Data) -> String {
        guard !data.isEmpty else { return "" }
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = object["message"] as? String {
            return message
        }
        return String(data: data, encoding: .utf8)?.trimmed ?? ""
    }
}

struct AppUpdateManifest: Decodable {
    var version: String?
    var tagName: String?
    var title: String?
    var name: String?
    var publishedAt: String?
    var releaseNotesEN: String?
    var releaseNotesZHHans: String?
    var releaseNotes: String?
    var body: String?
    var htmlURL: URL?
    var releaseURL: URL?
    var assets: AppUpdateManifestAssetCollection?
    var downloads: AppUpdateManifestAssetCollection?

    private enum CodingKeys: String, CodingKey {
        case version
        case tagName
        case tagNameSnake = "tag_name"
        case title
        case name
        case publishedAt
        case publishedAtSnake = "published_at"
        case releaseNotesEN = "release_notes_en"
        case releaseNotesZHHans = "release_notes_zh_hans"
        case releaseNotes
        case releaseNotesSnake = "release_notes"
        case body
        case htmlURL = "html_url"
        case releaseURL = "release_url"
        case assets
        case downloads
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(String.self, forKey: .version)
        tagName = try container.decodeIfPresent(String.self, forKey: .tagName)
            ?? container.decodeIfPresent(String.self, forKey: .tagNameSnake)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        publishedAt = try container.decodeIfPresent(String.self, forKey: .publishedAt)
            ?? container.decodeIfPresent(String.self, forKey: .publishedAtSnake)
        releaseNotesEN = try container.decodeIfPresent(String.self, forKey: .releaseNotesEN)
        releaseNotesZHHans = try container.decodeIfPresent(String.self, forKey: .releaseNotesZHHans)
        releaseNotes = try container.decodeIfPresent(String.self, forKey: .releaseNotes)
            ?? container.decodeIfPresent(String.self, forKey: .releaseNotesSnake)
        body = try container.decodeIfPresent(String.self, forKey: .body)
        htmlURL = try container.decodeIfPresent(URL.self, forKey: .htmlURL)
        releaseURL = try container.decodeIfPresent(URL.self, forKey: .releaseURL)
        assets = try container.decodeIfPresent(AppUpdateManifestAssetCollection.self, forKey: .assets)
        downloads = try container.decodeIfPresent(AppUpdateManifestAssetCollection.self, forKey: .downloads)
    }

    func release() throws -> AppUpdateRelease {
        let rawVersion = version ?? tagName ?? ""
        guard let semanticVersion = SemanticVersion(rawVersion) else {
            throw AppUpdateServiceError.invalidReleaseVersion(rawVersion)
        }

        let assets = (assets ?? downloads)?.entries.compactMap {
            $0.asset.appUpdateAsset(fallbackArchitecture: AppUpdateArchitecture(rawValue: $0.key ?? ""))
        } ?? []
        guard !assets.isEmpty else {
            throw AppUpdateServiceError.invalidManifest
        }

        let resolvedTag = tagName?.nilIfBlank ?? rawVersion
        let versionText = semanticVersion.normalizedText
        let resolvedTitle = [title, name, resolvedTag]
            .compactMap { $0?.nilIfBlank }
            .first ?? versionText

        return AppUpdateRelease(
            version: semanticVersion,
            versionText: versionText,
            tagName: resolvedTag,
            title: resolvedTitle,
            publishedAt: Self.date(from: publishedAt),
            releaseNotes: AppUpdateReleaseNotes.resolved(
                english: releaseNotesEN,
                simplifiedChinese: releaseNotesZHHans,
                legacy: releaseNotes ?? body
            ),
            htmlURL: htmlURL ?? releaseURL,
            assets: assets
        )
    }

    static func decodeRelease(from data: Data) throws -> AppUpdateRelease {
        try JSONDecoder().decode(AppUpdateManifest.self, from: data).release()
    }

    private static func date(from text: String?) -> Date? {
        guard let text = text?.nilIfBlank else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: text) {
            return date
        }
        return ISO8601DateFormatter().date(from: text)
    }
}

struct AppUpdateManifestAssetCollection: Decodable {
    struct Entry {
        var key: String?
        var asset: AppUpdateManifestAsset
    }

    var entries: [Entry]

    init(from decoder: Decoder) throws {
        if let array = try? [AppUpdateManifestAsset](from: decoder) {
            entries = array.map { Entry(key: nil, asset: $0) }
            return
        }

        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        entries = try container.allKeys.map { key in
            Entry(key: key.stringValue, asset: try container.decode(AppUpdateManifestAsset.self, forKey: key))
        }
    }
}

struct AppUpdateManifestAsset: Decodable {
    var architecture: String?
    var name: String?
    var url: URL?
    var downloadURL: URL?
    var browserDownloadURL: URL?
    var size: Int64?
    var digest: String?
    var sha256: String?
    var checksum: String?

    private enum CodingKeys: String, CodingKey {
        case architecture
        case arch
        case name
        case url
        case downloadURL
        case downloadURLSnake = "download_url"
        case browserDownloadURL
        case browserDownloadURLSnake = "browser_download_url"
        case size
        case digest
        case sha256
        case checksum
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        architecture = try container.decodeIfPresent(String.self, forKey: .architecture)
            ?? container.decodeIfPresent(String.self, forKey: .arch)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        url = try container.decodeIfPresent(URL.self, forKey: .url)
        downloadURL = try container.decodeIfPresent(URL.self, forKey: .downloadURL)
            ?? container.decodeIfPresent(URL.self, forKey: .downloadURLSnake)
        browserDownloadURL = try container.decodeIfPresent(URL.self, forKey: .browserDownloadURL)
            ?? container.decodeIfPresent(URL.self, forKey: .browserDownloadURLSnake)
        size = try container.decodeIfPresent(Int64.self, forKey: .size)
        digest = try container.decodeIfPresent(String.self, forKey: .digest)
        sha256 = try container.decodeIfPresent(String.self, forKey: .sha256)
        checksum = try container.decodeIfPresent(String.self, forKey: .checksum)
    }

    func appUpdateAsset(fallbackArchitecture: AppUpdateArchitecture?) -> AppUpdateAsset? {
        guard let downloadURL = browserDownloadURL ?? self.downloadURL ?? url else { return nil }
        let resolvedName = name?.nilIfBlank ?? downloadURL.lastPathComponent
        let resolvedArchitecture = AppUpdateArchitecture(rawValue: architecture ?? "") ?? fallbackArchitecture
        guard let resolvedSHA256 = Self.normalizedChecksum(digest: digest, sha256: sha256, checksum: checksum) else {
            return nil
        }
        return AppUpdateAsset(
            name: resolvedName,
            downloadURL: downloadURL,
            size: size ?? 0,
            sha256: resolvedSHA256,
            architecture: resolvedArchitecture
        )
    }

    private static func normalizedChecksum(digest: String?, sha256: String?, checksum: String?) -> String? {
        for candidate in [digest, sha256, checksum] {
            guard let value = candidate?.nilIfBlank else { continue }
            return value.lowercased().hasPrefix("sha256:") ? value : "sha256:\(value)"
        }
        return nil
    }
}

private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}
