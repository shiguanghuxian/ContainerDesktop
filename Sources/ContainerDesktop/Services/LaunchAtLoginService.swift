import Foundation
import ServiceManagement

@MainActor
protocol LaunchAtLoginServicing {
    var status: LaunchAtLoginStatus { get }

    func register() throws
    func unregister() throws
}

struct LaunchAtLoginService: LaunchAtLoginServicing {
    var bundleURLProvider: () -> URL = { Bundle.main.bundleURL }
    var executableURLProvider: () -> URL? = { Bundle.main.executableURL }
    var serviceStatusProvider: () -> SMAppService.Status = { SMAppService.mainApp.status }

    var status: LaunchAtLoginStatus {
        guard appBundleURL != nil else {
            return .unavailable(Self.unavailableLaunchModeDetail(
                bundleURL: bundleURLProvider(),
                executableURL: executableURLProvider()
            ))
        }
        return LaunchAtLoginStatus(serviceStatus: serviceStatusProvider())
    }

    func register() throws {
        guard appBundleURL != nil else {
            throw LaunchAtLoginServiceError.notRunningFromAppBundle
        }
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        guard appBundleURL != nil else {
            throw LaunchAtLoginServiceError.notRunningFromAppBundle
        }
        try SMAppService.mainApp.unregister()
    }

    private var appBundleURL: URL? {
        Self.appBundleURL(bundleURL: bundleURLProvider(), executableURL: executableURLProvider())
    }

    static func appBundleURL(bundleURL: URL, executableURL: URL?) -> URL? {
        if let bundleAppURL = appBundleAncestor(startingAt: bundleURL) {
            return bundleAppURL
        }
        guard let executableURL else { return nil }
        return appBundleAncestor(startingAt: executableURL)
    }

    private static func appBundleAncestor(startingAt url: URL) -> URL? {
        var currentURL = url.standardizedFileURL
        while true {
            if currentURL.pathExtension.localizedCaseInsensitiveCompare("app") == .orderedSame {
                return currentURL
            }
            let parentURL = currentURL.deletingLastPathComponent()
            guard parentURL.path != currentURL.path else { return nil }
            currentURL = parentURL
        }
    }

    private static func unavailableLaunchModeDetail(bundleURL: URL, executableURL: URL?) -> String {
        let executablePath = executableURL?.standardizedFileURL.path ?? "unknown executable"
        return "bundle: \(bundleURL.standardizedFileURL.path), executable: \(executablePath)"
    }
}

enum LaunchAtLoginServiceError: LocalizedError {
    case notRunningFromAppBundle

    var errorDescription: String? {
        switch self {
        case .notRunningFromAppBundle:
            "\(AppBranding.displayName) must be launched from a standard macOS app bundle to manage Login Items."
        }
    }
}

private extension LaunchAtLoginStatus {
    init(serviceStatus: SMAppService.Status) {
        switch serviceStatus {
        case .notRegistered:
            self = .notRegistered
        case .enabled:
            self = .enabled
        case .requiresApproval:
            self = .requiresApproval
        case .notFound:
            self = .notRegistered
        @unknown default:
            self = .unknown(String(describing: serviceStatus))
        }
    }
}
