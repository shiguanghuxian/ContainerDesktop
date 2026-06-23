import AppKit
import Foundation

struct SystemTerminalApp: Identifiable, Hashable, Sendable {
    static let systemDefaultID = "system-default"
    static let bundleIdentifierDefaultsKey = "containerdesktop.dockerCompatibilityTerminal.systemTerminalAppBundleID"

    var bundleIdentifier: String?
    var displayName: String
    var appURL: URL?
    var isSystemDefault: Bool
    var isAvailable: Bool

    var id: String {
        if isSystemDefault { return Self.systemDefaultID }
        if let bundleIdentifier { return bundleIdentifier }
        return appURL?.standardizedFileURL.path ?? displayName
    }

    var preferenceValue: String {
        isSystemDefault ? "" : (bundleIdentifier ?? "")
    }

    var pathText: String? {
        appURL?.standardizedFileURL.path
    }

    static var systemDefault: SystemTerminalApp {
        SystemTerminalApp(
            bundleIdentifier: nil,
            displayName: "System Default Terminal",
            appURL: nil,
            isSystemDefault: true,
            isAvailable: true
        )
    }

    static func missing(bundleIdentifier: String) -> SystemTerminalApp {
        SystemTerminalApp(
            bundleIdentifier: bundleIdentifier,
            displayName: bundleIdentifier,
            appURL: nil,
            isSystemDefault: false,
            isAvailable: false
        )
    }
}

enum SystemTerminalAppPreference {
    static let defaultsKey = SystemTerminalApp.bundleIdentifierDefaultsKey

    static func selectedBundleIdentifier(in defaults: UserDefaults = .containerDesktopShared) -> String? {
        guard let rawValue = defaults.string(forKey: defaultsKey)?.trimmed,
              !rawValue.isEmpty
        else {
            return nil
        }
        return rawValue
    }

    static func setSelectedBundleIdentifier(_ bundleIdentifier: String?, in defaults: UserDefaults = .containerDesktopShared) {
        guard let bundleIdentifier = bundleIdentifier?.trimmed,
              !bundleIdentifier.isEmpty
        else {
            defaults.removeObject(forKey: defaultsKey)
            return
        }
        defaults.set(bundleIdentifier, forKey: defaultsKey)
    }

    static func selectedTerminalApp(in defaults: UserDefaults = .containerDesktopShared) -> SystemTerminalApp? {
        guard let bundleIdentifier = selectedBundleIdentifier(in: defaults) else { return nil }
        return SystemTerminalAppDiscovery().terminalApp(bundleIdentifier: bundleIdentifier)
            ?? .missing(bundleIdentifier: bundleIdentifier)
    }
}

struct SystemTerminalAppDiscovery {
    static let knownTerminalBundleIdentifiers: [String] = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "dev.warp.Warp",
        "com.github.wez.wezterm",
        "org.alacritty",
        "net.kovidgoyal.kitty",
        "com.mitchellh.ghostty",
    ]

    private static let knownTerminalPriority: [String: Int] = Dictionary(
        uniqueKeysWithValues: knownTerminalBundleIdentifiers.enumerated().map { ($0.element, $0.offset) }
    )

    var workspace: NSWorkspace = .shared
    var fileManager: FileManager = .default

    func availableTerminalApps(including selectedBundleIdentifier: String? = nil) -> [SystemTerminalApp] {
        let commandURL = URL(fileURLWithPath: "/tmp/containerdesktop-terminal-discovery.command")
        var candidates: [SystemTerminalApp] = workspace.urlsForApplications(toOpen: commandURL)
            .compactMap(terminalApp(at:))

        for bundleIdentifier in Self.knownTerminalBundleIdentifiers {
            if let app = terminalApp(bundleIdentifier: bundleIdentifier) {
                candidates.append(app)
            }
        }

        if let selectedBundleIdentifier,
           !selectedBundleIdentifier.isEmpty,
           !candidates.contains(where: { $0.bundleIdentifier == selectedBundleIdentifier }) {
            candidates.append(terminalApp(bundleIdentifier: selectedBundleIdentifier) ?? .missing(bundleIdentifier: selectedBundleIdentifier))
        }

        return Self.normalized(candidates)
    }

    func terminalApp(bundleIdentifier: String) -> SystemTerminalApp? {
        guard let appURL = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }
        return terminalApp(at: appURL)
    }

    func terminalApp(at appURL: URL) -> SystemTerminalApp? {
        let standardizedURL = appURL.standardizedFileURL
        guard standardizedURL.pathExtension == "app" else { return nil }

        let bundle = Bundle(url: standardizedURL)
        guard let bundleIdentifier = bundle?.bundleIdentifier?.trimmed,
              !bundleIdentifier.isEmpty
        else {
            return nil
        }
        let displayName = Self.displayName(for: standardizedURL, bundle: bundle, fileManager: fileManager)

        return SystemTerminalApp(
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            appURL: standardizedURL,
            isSystemDefault: false,
            isAvailable: true
        )
    }

    static func normalized(_ candidates: [SystemTerminalApp]) -> [SystemTerminalApp] {
        var seen = Set<String>()
        var unique: [SystemTerminalApp] = []

        for app in candidates where !app.isSystemDefault {
            let key = app.bundleIdentifier?.lowercased()
                ?? app.appURL?.standardizedFileURL.path.lowercased()
                ?? app.displayName.lowercased()
            guard seen.insert(key).inserted else { continue }
            unique.append(app)
        }

        unique.sort { lhs, rhs in
            let lhsPriority = lhs.bundleIdentifier.flatMap { knownTerminalPriority[$0] } ?? Int.max
            let rhsPriority = rhs.bundleIdentifier.flatMap { knownTerminalPriority[$0] } ?? Int.max
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }

        return [.systemDefault] + unique
    }

    private static func displayName(for appURL: URL, bundle: Bundle?, fileManager: FileManager) -> String {
        if let displayName = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !displayName.trimmed.isEmpty {
            return displayName
        }

        if let bundleName = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String,
           !bundleName.trimmed.isEmpty {
            return bundleName
        }

        return fileManager.displayName(atPath: appURL.path).replacingOccurrences(of: ".app", with: "")
    }
}
