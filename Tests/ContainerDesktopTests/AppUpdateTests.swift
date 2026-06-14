import Foundation
import Testing
@testable import ContainerDesktop

private final class AppUpdateMockURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    private final class State: @unchecked Sendable {
        let lock = NSLock()
        var handler: Handler?
        var requests: [URLRequest] = []
    }

    private static let state = State()

    static func setHandler(_ handler: @escaping Handler) {
        state.lock.lock()
        defer { state.lock.unlock() }
        state.handler = handler
        state.requests = []
    }

    static func reset() {
        state.lock.lock()
        defer { state.lock.unlock() }
        state.handler = nil
        state.requests = []
    }

    static func recordedRequests() -> [URLRequest] {
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.requests
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.state.lock.lock()
        let handler = Self.state.handler
        Self.state.requests.append(request)
        Self.state.lock.unlock()

        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private final class AppUpdateServiceStub: AppUpdateServicing, @unchecked Sendable {
    var checkResult: Result<AppUpdateCheckResult, Error>
    var downloadResult: Result<AppUpdateDownloadedPackage, Error>
    private(set) var checkCallCount = 0
    private(set) var downloadCallCount = 0

    init(
        checkResult: Result<AppUpdateCheckResult, Error>,
        downloadResult: Result<AppUpdateDownloadedPackage, Error>? = nil
    ) {
        self.checkResult = checkResult
        self.downloadResult = downloadResult ?? .failure(AppUpdateServiceError.invalidManifest)
    }

    func checkForUpdate(currentVersion: String, architecture: AppUpdateArchitecture) async throws -> AppUpdateCheckResult {
        checkCallCount += 1
        return try checkResult.get()
    }

    func download(
        package: AppUpdatePackage,
        progress: (@Sendable (Double?) -> Void)?
    ) async throws -> AppUpdateDownloadedPackage {
        downloadCallCount += 1
        progress?(0.5)
        return try downloadResult.get()
    }
}

private final class AppUpdateInstallerStub: AppUpdateInstalling, @unchecked Sendable {
    var prepareError: Error?
    var launchError: Error?
    private(set) var prepareCallCount = 0
    private(set) var launchCallCount = 0

    func prepareInstallation(
        downloadedPackage: AppUpdateDownloadedPackage,
        currentAppURL: URL?,
        currentVersion: String
    ) async throws -> AppUpdatePreparedInstallation {
        prepareCallCount += 1
        if let prepareError {
            throw prepareError
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        return AppUpdatePreparedInstallation(
            downloadedPackage: downloadedPackage,
            scriptURL: root.appendingPathComponent("install.sh"),
            currentAppURL: currentAppURL ?? root.appendingPathComponent("ContainerDesktop.app", isDirectory: true),
            extractedAppURL: root.appendingPathComponent("expanded/ContainerDesktop.app", isDirectory: true),
            backupURL: root.appendingPathComponent("ContainerDesktop.previous.app", isDirectory: true)
        )
    }

    func launchInstallation(_ installation: AppUpdatePreparedInstallation) async throws {
        launchCallCount += 1
        if let launchError {
            throw launchError
        }
    }
}

@Suite("App updates", .serialized)
struct AppUpdateTests {
    @Test("semantic versions compare with v prefix and missing patch")
    func semanticVersionsCompareWithPrefix() {
        #expect(SemanticVersion("v1.2.0")! > SemanticVersion("1.1.9")!)
        #expect(SemanticVersion("1.2")! == SemanticVersion("1.2.0")!)
        #expect(SemanticVersion("") == nil)
        #expect(SemanticVersion("abc") == nil)
    }

    @Test("appcast manifest decodes architecture asset")
    func appcastManifestDecodesArchitectureAsset() throws {
        let release = try AppUpdateManifest.decodeRelease(from: Data(Self.manifestJSON(version: "1.0.1").utf8))

        #expect(release.versionText == "1.0.1")
        #expect(release.tagName == "1.0.1")
        #expect(release.htmlURL?.absoluteString == "https://github.com/shiguanghuxian/ContainerDesktop/releases/tag/1.0.1")
        let asset = try #require(release.compatibleAsset(for: .arm64))
        #expect(asset.name == "ContainerDesktop-1.0.1-100-arm64.zip")
        #expect(asset.downloadURL.absoluteString == "https://example.test/ContainerDesktop-1.0.1-100-arm64.zip")
        #expect(asset.normalizedSHA256 == "abcdef")
    }

    @Test("update check reports available and up to date")
    func updateCheckReportsAvailableAndUpToDate() async throws {
        defer { AppUpdateMockURLProtocol.reset() }
        let service = Self.makeService(json: Self.manifestJSON(version: "1.0.1"))

        let available = try await service.checkForUpdate(currentVersion: "1.0.0", architecture: .arm64)
        guard case .updateAvailable(let package) = available else {
            Issue.record("Expected updateAvailable")
            return
        }
        #expect(package.versionText == "1.0.1")

        AppUpdateMockURLProtocol.setHandler { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(Self.manifestJSON(version: "1.0.0").utf8))
        }
        let current = try await service.checkForUpdate(currentVersion: "1.0.0", architecture: .arm64)
        guard case .upToDate(let release) = current else {
            Issue.record("Expected upToDate")
            return
        }
        #expect(release.versionText == "1.0.0")
    }

    @Test("appcast cache sends etag and uses cached 304 response")
    func appcastCacheUsesETagFor304() async throws {
        defer { AppUpdateMockURLProtocol.reset() }
        let root = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let manifestURL = URL(string: "https://updates.example.test/appcast.json")!
        let cacheStore = AppUpdateResponseCacheStore(directory: root)
        let cachedResponse = HTTPURLResponse(
            url: manifestURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["ETag": #""manifest-v1""#]
        )!
        cacheStore.save(key: "appcast", url: manifestURL, response: cachedResponse, data: Data(Self.manifestJSON(version: "1.0.1").utf8))

        let service = Self.makeService(
            manifestURL: manifestURL,
            statusCode: 304,
            json: "",
            cacheStore: cacheStore
        )

        let result = try await service.checkForUpdate(currentVersion: "1.0.0", architecture: .arm64)
        guard case .updateAvailable(let package) = result else {
            Issue.record("Expected cached updateAvailable")
            return
        }
        #expect(package.versionText == "1.0.1")
        #expect(AppUpdateMockURLProtocol.recordedRequests().first?.value(forHTTPHeaderField: "If-None-Match") == #""manifest-v1""#)
    }

    @Test("checksum mismatch deletes downloaded file")
    func checksumMismatchDeletesDownloadedFile() throws {
        let root = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fileURL = root.appendingPathComponent("update.zip")
        try Data("payload".utf8).write(to: fileURL)
        let service = AppUpdateService()
        let asset = AppUpdateAsset(
            name: "update.zip",
            downloadURL: URL(string: "https://example.test/update.zip")!,
            size: 7,
            sha256: "sha256:deadbeef",
            architecture: .arm64
        )

        do {
            try service.verifyChecksum(for: fileURL, asset: asset)
            Issue.record("Expected checksum mismatch")
        } catch let error as AppUpdateServiceError {
            guard case .checksumMismatch = error else {
                Issue.record("Expected checksumMismatch, got \(error)")
                return
            }
            #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        }
    }

    @Test("installer prepares valid update package")
    func installerPreparesValidUpdatePackage() async throws {
        let root = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let currentApp = try Self.makeAppBundle(
            root: root.appendingPathComponent("current", isDirectory: true),
            version: "1.0.0"
        )
        let updateApp = try Self.makeAppBundle(
            root: root.appendingPathComponent("payload", isDirectory: true),
            version: "1.0.1"
        )
        let zipURL = root.appendingPathComponent("update.zip")
        try await AppUpdateInstaller.runProcess("/usr/bin/ditto", ["-c", "-k", "--keepParent", updateApp.path, zipURL.path])
        let installer = AppUpdateInstaller(
            temporaryDirectory: root,
            codeSignatureValidator: { _ in }
        )
        let prepared = try await installer.prepareInstallation(
            downloadedPackage: Self.downloadedPackage(version: "1.0.1", fileURL: zipURL),
            currentAppURL: currentApp,
            currentVersion: "1.0.0"
        )

        #expect(prepared.currentAppURL == currentApp)
        #expect(prepared.extractedAppURL.lastPathComponent == "ContainerDesktop.app")
        #expect(FileManager.default.fileExists(atPath: prepared.scriptURL.path))
    }

    @Test("installer rejects invalid app bundle")
    func installerRejectsInvalidAppBundle() async throws {
        let root = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let currentApp = try Self.makeAppBundle(
            root: root.appendingPathComponent("current", isDirectory: true),
            version: "1.0.0"
        )
        let updateApp = try Self.makeAppBundle(
            root: root.appendingPathComponent("payload", isDirectory: true),
            bundleIdentifier: "com.example.BadApp",
            version: "1.0.1"
        )
        let zipURL = root.appendingPathComponent("bad.zip")
        try await AppUpdateInstaller.runProcess("/usr/bin/ditto", ["-c", "-k", "--keepParent", updateApp.path, zipURL.path])
        let installer = AppUpdateInstaller(
            temporaryDirectory: root,
            codeSignatureValidator: { _ in }
        )

        do {
            _ = try await installer.prepareInstallation(
                downloadedPackage: Self.downloadedPackage(version: "1.0.1", fileURL: zipURL),
                currentAppURL: currentApp,
                currentVersion: "1.0.0"
            )
            Issue.record("Expected invalid bundle identifier")
        } catch let error as AppUpdateInstallerError {
            #expect(error == .invalidBundleIdentifier("com.example.BadApp"))
        }
    }

    @Test("store respects automatic interval and download install states")
    @MainActor
    func storeRespectsAutomaticIntervalAndDownloadInstallStates() async throws {
        let release = Self.release(version: "1.0.1")
        let package = AppUpdatePackage(release: release, asset: release.assets[0])
        let downloaded = AppUpdateDownloadedPackage(
            package: package,
            fileURL: URL(fileURLWithPath: "/tmp/update.zip")
        )
        let service = AppUpdateServiceStub(
            checkResult: .success(.updateAvailable(package)),
            downloadResult: .success(downloaded)
        )
        let installer = AppUpdateInstallerStub()
        let defaults = try Self.makeUserDefaults()
        var now = Date(timeIntervalSince1970: 1_000)
        var terminated = false
        let store = AppUpdateStore(
            service: service,
            installer: installer,
            userDefaults: defaults,
            nowProvider: { now },
            openURL: { _ in },
            terminateApplication: { terminated = true }
        )

        await store.checkForUpdatesIfNeededOnLaunch()
        #expect(service.checkCallCount == 1)
        guard case .updateAvailable = store.status else {
            Issue.record("Expected updateAvailable")
            return
        }

        await store.checkForUpdatesIfNeededOnLaunch()
        #expect(service.checkCallCount == 1)
        now = Date(timeIntervalSince1970: 1_000 + 24 * 60 * 60 + 1)
        await store.checkForUpdatesIfNeededOnLaunch()
        #expect(service.checkCallCount == 2)

        await store.downloadUpdate(package)
        #expect(service.downloadCallCount == 1)
        guard case .readyToInstall(let ready) = store.status else {
            Issue.record("Expected readyToInstall")
            return
        }
        await store.installDownloadedUpdate(ready)
        #expect(installer.prepareCallCount == 1)
        #expect(installer.launchCallCount == 1)
        #expect(terminated)
    }

    private static func makeService(
        manifestURL: URL = URL(string: "https://updates.example.test/appcast.json")!,
        statusCode: Int = 200,
        headers: [String: String] = [:],
        json: String,
        cacheStore: AppUpdateResponseCacheStore = AppUpdateResponseCacheStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true))
    ) -> AppUpdateService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AppUpdateMockURLProtocol.self]
        AppUpdateMockURLProtocol.setHandler { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: headers
            )!
            return (response, Data(json.utf8))
        }
        return AppUpdateService(
            manifestURL: manifestURL,
            session: URLSession(configuration: configuration),
            cacheStore: cacheStore
        )
    }

    private static func manifestJSON(version: String) -> String {
        """
        {
          "version": "\(version)",
          "tag_name": "\(version)",
          "title": "ContainerDesktop \(version)",
          "published_at": "2026-06-14T00:00:00Z",
          "release_notes": "Release notes",
          "html_url": "https://github.com/shiguanghuxian/ContainerDesktop/releases/tag/\(version)",
          "assets": {
            "arm64": {
              "name": "ContainerDesktop-\(version)-100-arm64.zip",
              "download_url": "https://example.test/ContainerDesktop-\(version)-100-arm64.zip",
              "size": 123456,
              "sha256": "abcdef"
            }
          }
        }
        """
    }

    private static func release(version: String) -> AppUpdateRelease {
        AppUpdateRelease(
            version: SemanticVersion(version)!,
            versionText: version,
            tagName: version,
            title: "ContainerDesktop \(version)",
            publishedAt: nil,
            releaseNotes: "Release notes",
            htmlURL: URL(string: "https://example.test/releases/\(version)")!,
            assets: [
                AppUpdateAsset(
                    name: "ContainerDesktop-\(version)-100-arm64.zip",
                    downloadURL: URL(string: "https://example.test/ContainerDesktop-\(version)-100-arm64.zip")!,
                    size: 100,
                    sha256: "sha256:abcdef",
                    architecture: .arm64
                ),
            ]
        )
    }

    private static func downloadedPackage(version: String, fileURL: URL) -> AppUpdateDownloadedPackage {
        let release = release(version: version)
        return AppUpdateDownloadedPackage(
            package: AppUpdatePackage(release: release, asset: release.assets[0]),
            fileURL: fileURL
        )
    }

    private static func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func makeUserDefaults() throws -> UserDefaults {
        let suiteName = "ContainerDesktopTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private static func makeAppBundle(
        root: URL,
        bundleIdentifier: String = AppPaths.bundleIdentifier,
        version: String,
        executableName: String = AppUpdateRuntime.executableName
    ) throws -> URL {
        let appURL = root.appendingPathComponent("ContainerDesktop.app", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        let macOSURL = contentsURL.appendingPathComponent("MacOS", isDirectory: true)
        try FileManager.default.createDirectory(at: macOSURL, withIntermediateDirectories: true)
        let info: [String: Any] = [
            "CFBundleIdentifier": bundleIdentifier,
            "CFBundleShortVersionString": version,
            "CFBundleVersion": "100",
            "CFBundleExecutable": executableName,
        ]
        let infoData = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try infoData.write(to: contentsURL.appendingPathComponent("Info.plist"))
        let executableURL = macOSURL.appendingPathComponent(executableName)
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executableURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)
        return appURL
    }
}
