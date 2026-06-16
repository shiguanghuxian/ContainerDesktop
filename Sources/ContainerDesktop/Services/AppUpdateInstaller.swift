import Foundation

enum AppUpdateInstallerError: LocalizedError, Hashable {
    case currentAppUnavailable
    case currentAppNotWritable(String)
    case invalidPackage
    case extractedAppNotFound
    case multipleExtractedApps
    case invalidBundleIdentifier(String)
    case missingExecutable(String)
    case invalidBundleVersion(String)
    case versionNotNewer(current: String, candidate: String)
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .currentAppUnavailable:
            return "The current app bundle could not be located."
        case .currentAppNotWritable(let path):
            return "The app cannot be updated in place because its folder is not writable: \(path)"
        case .invalidPackage:
            return "The downloaded update package is not a valid \(AppBranding.displayName) zip archive."
        case .extractedAppNotFound:
            return "The update package did not contain the expected \(AppBranding.displayName) app bundle."
        case .multipleExtractedApps:
            return "The update package contained more than one app bundle."
        case .invalidBundleIdentifier(let value):
            return "The update app bundle identifier is invalid: \(value)"
        case .missingExecutable(let path):
            return "The update app executable was not found: \(path)"
        case .invalidBundleVersion(let version):
            return "The update app version is invalid: \(version)"
        case .versionNotNewer(let current, let candidate):
            return "The update version \(candidate) is not newer than the current version \(current)."
        case .launchFailed(let detail):
            return "Could not start the update installer: \(detail)"
        }
    }
}

struct AppUpdatePreparedInstallation: Hashable, Sendable {
    var downloadedPackage: AppUpdateDownloadedPackage
    var scriptURL: URL
    var currentAppURL: URL
    var extractedAppURL: URL
    var backupURL: URL
}

protocol AppUpdateInstalling: Sendable {
    func prepareInstallation(
        downloadedPackage: AppUpdateDownloadedPackage,
        currentAppURL: URL?,
        currentVersion: String
    ) async throws -> AppUpdatePreparedInstallation

    func launchInstallation(_ installation: AppUpdatePreparedInstallation) async throws
}

struct AppUpdateInstaller: AppUpdateInstalling, @unchecked Sendable {
    private let fileManager: FileManager
    private let temporaryDirectory: URL
    private let processIdentifierProvider: @Sendable () -> Int32
    private let codeSignatureValidator: @Sendable (URL) async throws -> Void

    init(
        fileManager: FileManager = .default,
        temporaryDirectory: URL = FileManager.default.temporaryDirectory,
        processIdentifierProvider: @escaping @Sendable () -> Int32 = { ProcessInfo.processInfo.processIdentifier },
        codeSignatureValidator: @escaping @Sendable (URL) async throws -> Void = { appURL in
            try await Self.runProcess("/usr/bin/codesign", ["--verify", "--deep", "--strict", appURL.path])
        }
    ) {
        self.fileManager = fileManager
        self.temporaryDirectory = temporaryDirectory
        self.processIdentifierProvider = processIdentifierProvider
        self.codeSignatureValidator = codeSignatureValidator
    }

    func prepareInstallation(
        downloadedPackage: AppUpdateDownloadedPackage,
        currentAppURL providedCurrentAppURL: URL? = Bundle.main.bundleURL,
        currentVersion: String = AppUpdateRuntime.releaseVersion
    ) async throws -> AppUpdatePreparedInstallation {
        guard let currentAppURL = Self.normalizedAppBundleURL(providedCurrentAppURL) else {
            throw AppUpdateInstallerError.currentAppUnavailable
        }

        let parentDirectory = currentAppURL.deletingLastPathComponent()
        guard fileManager.isWritableFile(atPath: parentDirectory.path) else {
            throw AppUpdateInstallerError.currentAppNotWritable(parentDirectory.path)
        }

        let workDirectory = temporaryDirectory
            .appendingPathComponent("containerdesktop-install-\(UUID().uuidString)", isDirectory: true)
        let extractDirectory = workDirectory.appendingPathComponent("expanded", isDirectory: true)
        try fileManager.createDirectory(at: extractDirectory, withIntermediateDirectories: true)

        try await Self.runProcess("/usr/bin/ditto", ["-x", "-k", downloadedPackage.fileURL.path, extractDirectory.path])
        let extractedAppURL = try findExtractedApp(in: extractDirectory)
        try validateExtractedApp(extractedAppURL, currentVersion: currentVersion)
        try await codeSignatureValidator(extractedAppURL)

        let backupURL = parentDirectory.appendingPathComponent(
            "\(currentAppURL.deletingPathExtension().lastPathComponent).previous-update-\(Self.timestamp()).app"
        )
        let scriptURL = workDirectory.appendingPathComponent("install-update.sh")
        try writeInstallerScript(
            scriptURL: scriptURL,
            currentAppURL: currentAppURL,
            extractedAppURL: extractedAppURL,
            backupURL: backupURL
        )

        return AppUpdatePreparedInstallation(
            downloadedPackage: downloadedPackage,
            scriptURL: scriptURL,
            currentAppURL: currentAppURL,
            extractedAppURL: extractedAppURL,
            backupURL: backupURL
        )
    }

    func launchInstallation(_ installation: AppUpdatePreparedInstallation) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [
            installation.scriptURL.path,
            String(processIdentifierProvider()),
        ]
        do {
            try process.run()
        } catch {
            throw AppUpdateInstallerError.launchFailed(error.localizedDescription)
        }
    }

    private func findExtractedApp(in extractDirectory: URL) throws -> URL {
        guard let enumerator = fileManager.enumerator(
            at: extractDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw AppUpdateInstallerError.invalidPackage
        }

        var appURLs: [URL] = []
        for case let url as URL in enumerator {
            guard url.pathExtension == "app" else { continue }
            appURLs.append(url)
            enumerator.skipDescendants()
        }

        guard !appURLs.isEmpty else {
            throw AppUpdateInstallerError.extractedAppNotFound
        }
        guard appURLs.count == 1 else {
            throw AppUpdateInstallerError.multipleExtractedApps
        }
        guard appURLs[0].lastPathComponent == "\(AppUpdateRuntime.appName).app" else {
            throw AppUpdateInstallerError.extractedAppNotFound
        }
        return appURLs[0]
    }

    private func validateExtractedApp(_ appURL: URL, currentVersion: String) throws {
        let executableURL = appURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("MacOS")
            .appendingPathComponent(AppUpdateRuntime.executableName)
        guard fileManager.fileExists(atPath: executableURL.path) else {
            throw AppUpdateInstallerError.missingExecutable(executableURL.path)
        }

        guard let bundle = Bundle(url: appURL) else {
            throw AppUpdateInstallerError.invalidPackage
        }
        let bundleIdentifier = bundle.bundleIdentifier ?? ""
        guard bundleIdentifier == AppUpdateRuntime.bundleIdentifier else {
            throw AppUpdateInstallerError.invalidBundleIdentifier(bundleIdentifier)
        }
        let candidateVersionText = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        guard let candidateVersion = SemanticVersion(candidateVersionText) else {
            throw AppUpdateInstallerError.invalidBundleVersion(candidateVersionText)
        }
        guard let current = SemanticVersion(currentVersion) else {
            throw AppUpdateInstallerError.invalidBundleVersion(currentVersion)
        }
        guard candidateVersion > current else {
            throw AppUpdateInstallerError.versionNotNewer(current: currentVersion, candidate: candidateVersionText)
        }
    }

    private func writeInstallerScript(
        scriptURL: URL,
        currentAppURL: URL,
        extractedAppURL: URL,
        backupURL: URL
    ) throws {
        let script = """
        #!/bin/bash
        set -euo pipefail

        CURRENT_PID="$1"
        CURRENT_APP=\(Self.shellQuoted(currentAppURL.path))
        NEW_APP=\(Self.shellQuoted(extractedAppURL.path))
        BACKUP_APP=\(Self.shellQuoted(backupURL.path))

        while /bin/kill -0 "$CURRENT_PID" >/dev/null 2>&1; do
          /bin/sleep 0.25
        done

        if [[ ! -d "$NEW_APP" ]]; then
          /usr/bin/osascript -e 'display alert "\(AppBranding.displayName) update failed" message "The downloaded update did not contain the new app."' >/dev/null 2>&1 || true
          exit 1
        fi

        rm -rf "$BACKUP_APP"
        if [[ -d "$CURRENT_APP" ]]; then
          /bin/mv "$CURRENT_APP" "$BACKUP_APP"
        fi

        if /bin/mv "$NEW_APP" "$CURRENT_APP"; then
          /usr/bin/open "$CURRENT_APP"
          rm -rf "$BACKUP_APP"
          exit 0
        fi

        rm -rf "$CURRENT_APP"
        if [[ -d "$BACKUP_APP" ]]; then
          /bin/mv "$BACKUP_APP" "$CURRENT_APP"
          /usr/bin/open "$CURRENT_APP"
        fi
        /usr/bin/osascript -e 'display alert "\(AppBranding.displayName) update failed" message "The old version was restored after replacement failed."' >/dev/null 2>&1 || true
        exit 1
        """
        guard let data = script.data(using: .utf8) else {
            throw AppUpdateInstallerError.invalidPackage
        }
        try data.write(to: scriptURL, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
    }

    private static func normalizedAppBundleURL(_ url: URL?) -> URL? {
        guard var url else { return nil }
        while url.pathExtension != "app" {
            let parent = url.deletingLastPathComponent()
            guard parent.path != url.path else { return nil }
            url = parent
        }
        return url
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: Date())
    }

    private static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func runProcess(_ executable: String, _ arguments: [String]) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            let stderr = Pipe()
            process.standardError = stderr
            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    let detail = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    continuation.resume(throwing: AppUpdateInstallerError.launchFailed(detail.trimmed))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
