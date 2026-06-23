import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class AppUpdateStore {
    static let automaticChecksEnabledKey = "containerdesktop.updates.automaticChecksEnabled"
    static let lastCheckAtKey = "containerdesktop.updates.lastCheckAt"

    @ObservationIgnored private let service: AppUpdateServicing
    @ObservationIgnored private let installer: AppUpdateInstalling
    @ObservationIgnored private let userDefaults: UserDefaults
    @ObservationIgnored private let nowProvider: () -> Date
    @ObservationIgnored private let openURL: (URL) -> Void
    @ObservationIgnored private let terminateApplication: () -> Void

    var status: AppUpdateStatus = .idle
    var automaticChecksEnabled: Bool {
        didSet {
            userDefaults.set(automaticChecksEnabled, forKey: Self.automaticChecksEnabledKey)
        }
    }
    var lastCheckAt: Date? {
        didSet {
            userDefaults.set(lastCheckAt, forKey: Self.lastCheckAtKey)
        }
    }

    let automaticCheckInterval: TimeInterval = 24 * 60 * 60

    init(
        service: AppUpdateServicing = AppUpdateService(),
        installer: AppUpdateInstalling = AppUpdateInstaller(),
        userDefaults: UserDefaults = .standard,
        nowProvider: @escaping () -> Date = Date.init,
        openURL: @escaping (URL) -> Void = { NSWorkspace.shared.open($0) },
        terminateApplication: @escaping () -> Void = { NSApp.terminate(nil) }
    ) {
        self.service = service
        self.installer = installer
        self.userDefaults = userDefaults
        self.nowProvider = nowProvider
        self.openURL = openURL
        self.terminateApplication = terminateApplication
        if userDefaults.object(forKey: Self.automaticChecksEnabledKey) == nil {
            automaticChecksEnabled = true
        } else {
            automaticChecksEnabled = userDefaults.bool(forKey: Self.automaticChecksEnabledKey)
        }
        lastCheckAt = userDefaults.object(forKey: Self.lastCheckAtKey) as? Date
    }

    var currentVersionText: String {
        AppUpdateRuntime.displayVersion
    }

    var latestVersionText: String {
        switch status {
        case .upToDate(let release):
            return release.versionText
        case .updateAvailable(let package), .downloading(let package, _), .installing(let package):
            return package.versionText
        case .readyToInstall(let downloaded):
            return downloaded.package.versionText
        case .idle, .checking, .failed:
            return "—"
        }
    }

    var releaseNotesText: String? {
        releaseNotesText(for: .en)
    }

    func releaseNotesText(for language: AppLanguage) -> String? {
        let notes: String
        switch status {
        case .upToDate(let release):
            notes = release.releaseNotes.text(for: language)
        case .updateAvailable(let package), .downloading(let package, _), .installing(let package):
            notes = package.releaseNotes(for: language)
        case .readyToInstall(let downloaded):
            notes = downloaded.package.releaseNotes(for: language)
        case .idle, .checking, .failed:
            return nil
        }
        let normalized = notes.replacingOccurrences(of: "\r\n", with: "\n").trimmed
        guard !normalized.isEmpty else { return nil }
        return normalized
    }

    var canRunPrimaryAction: Bool {
        switch status {
        case .checking, .downloading, .installing:
            return false
        case .idle, .upToDate, .updateAvailable, .readyToInstall, .failed:
            return true
        }
    }

    func shouldRunAutomaticUpdateCheck(now: Date = Date()) -> Bool {
        guard automaticChecksEnabled else { return false }
        guard let lastCheckAt else { return true }
        return now.timeIntervalSince(lastCheckAt) >= automaticCheckInterval
    }

    func checkForUpdatesIfNeededOnLaunch() async {
        guard shouldRunAutomaticUpdateCheck(now: nowProvider()) else { return }
        await checkForUpdates(isAutomatic: true)
    }

    func checkForUpdates(isAutomatic: Bool) async {
        guard canStartUpdateCheck(isAutomatic: isAutomatic) else { return }
        status = .checking
        if isAutomatic {
            lastCheckAt = nowProvider()
        }

        do {
            let result = try await service.checkForUpdate(
                currentVersion: AppUpdateRuntime.releaseVersion,
                architecture: .current
            )
            switch result {
            case .upToDate(let release):
                status = .upToDate(release)
            case .updateAvailable(let package):
                status = .updateAvailable(package)
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func downloadUpdate(_ package: AppUpdatePackage) async {
        status = .downloading(package, progress: nil)
        do {
            let downloaded = try await service.download(package: package, progress: nil)
            status = .readyToInstall(downloaded)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func installDownloadedUpdate(_ downloaded: AppUpdateDownloadedPackage) async {
        status = .installing(downloaded.package)
        do {
            let prepared = try await installer.prepareInstallation(
                downloadedPackage: downloaded,
                currentAppURL: Bundle.main.bundleURL,
                currentVersion: AppUpdateRuntime.releaseVersion
            )
            try await installer.launchInstallation(prepared)
            terminateApplication()
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func runPrimaryAction() async {
        switch status {
        case .idle, .upToDate, .failed:
            await checkForUpdates(isAutomatic: false)
        case .updateAvailable(let package):
            await downloadUpdate(package)
        case .readyToInstall(let downloaded):
            await installDownloadedUpdate(downloaded)
        case .checking, .downloading, .installing:
            return
        }
    }

    func openReleasePage() {
        let url: URL?
        switch status {
        case .upToDate(let release):
            url = release.htmlURL
        case .updateAvailable(let package), .downloading(let package, _), .installing(let package):
            url = package.release.htmlURL
        case .readyToInstall(let downloaded):
            url = downloaded.package.release.htmlURL
        case .idle, .checking, .failed:
            url = URL(string: "https://github.com/shiguanghuxian/ContainerDesktop/releases")
        }
        guard let url else { return }
        openURL(url)
    }

    private func canStartUpdateCheck(isAutomatic: Bool) -> Bool {
        switch status {
        case .checking, .downloading, .installing:
            return false
        case .idle, .upToDate, .updateAvailable, .readyToInstall, .failed:
            return isAutomatic ? automaticChecksEnabled : true
        }
    }
}
