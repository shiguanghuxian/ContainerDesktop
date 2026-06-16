import Foundation

enum ComponentVersionIDs {
    static let container = "container"
    static let containerCompose = "container-compose"

    static func runtime(_ name: String) -> String {
        "runtime:\(name)"
    }
}

enum ComponentVersionStatus: Hashable, Sendable {
    case missing
    case unchecked
    case upToDate
    case updateAvailable
    case unableToCompare

    func title(language: AppLanguage) -> String {
        switch self {
        case .missing:
            language.resolved == .zhHans ? "未安装" : "Missing"
        case .unchecked:
            language.resolved == .zhHans ? "未检查" : "Unchecked"
        case .upToDate:
            language.resolved == .zhHans ? "已是最新" : "Current"
        case .updateAvailable:
            language.resolved == .zhHans ? "可升级" : "Update Available"
        case .unableToCompare:
            language.resolved == .zhHans ? "无法比较" : "Unable to Compare"
        }
    }
}

struct ComponentLatestVersion: Hashable, Sendable {
    var componentID: String
    var version: String
    var releaseURL: URL?
    var sourceName: String
}

struct ComponentLatestVersionCheck: Hashable, Sendable {
    var latestVersions: [String: ComponentLatestVersion] = [:]
    var errors: [String] = []

    var hasChecked: Bool {
        !latestVersions.isEmpty || !errors.isEmpty
    }

    var errorMessage: String? {
        errors.isEmpty ? nil : errors.joined(separator: "\n")
    }

    func latestVersion(for componentID: String) -> ComponentLatestVersion? {
        latestVersions[componentID]
    }
}

struct ComponentVersionItem: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var sourceDescription: String
    var isInstalled: Bool
    var rawCurrentVersion: String?
    var currentVersion: String?
    var latestVersion: String?
    var latestVersionSource: String?
    var releaseURL: URL?
    var upgradeCommand: String?
    var status: ComponentVersionStatus

    var currentVersionDisplay: String {
        guard isInstalled else { return "missing" }
        return currentVersion ?? rawCurrentVersion?.nilIfBlank ?? "available"
    }

    var latestVersionDisplay: String {
        latestVersion ?? "—"
    }
}

enum ComponentVersionParser {
    static func semanticVersion(from rawValue: String?) -> SemanticVersion? {
        guard let text = semanticVersionText(from: rawValue) else { return nil }
        return SemanticVersion(text)
    }

    static func semanticVersionText(from rawValue: String?) -> String? {
        guard let rawValue = rawValue?.nilIfBlank else { return nil }
        let pattern = #"(?i)\bv?\d+(?:\.\d+){1,3}(?:[-+][A-Za-z0-9.\-]+)?\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(rawValue.startIndex..<rawValue.endIndex, in: rawValue)
        guard let match = regex.firstMatch(in: rawValue, range: range),
              let versionRange = Range(match.range, in: rawValue)
        else {
            return nil
        }
        return SemanticVersion(String(rawValue[versionRange]))?.normalizedText
    }

    static func displayVersion(from rawValue: String?) -> String? {
        semanticVersionText(from: rawValue) ?? rawValue?.nilIfBlank
    }
}

enum ComponentVersionCatalog {
    static let containerUpgradeCommand = DependencyInstallTarget.container.displayCommand
    static let containerComposeUpgradeCommand = "brew update && brew upgrade container-compose"

    static func makeItems(
        environment: EnvironmentProbe,
        systemVersions: [SystemVersionEntry],
        latestCheck: ComponentLatestVersionCheck?
    ) -> [ComponentVersionItem] {
        var items: [ComponentVersionItem] = []
        let containerSystemVersion = systemVersions.first { $0.appName.caseInsensitiveCompare(ComponentVersionIDs.container) == .orderedSame }?.version
        items.append(
            makeItem(
                id: ComponentVersionIDs.container,
                name: "container",
                sourceDescription: "container --version",
                isInstalled: environment.containerAvailable,
                rawCurrentVersion: environment.containerVersion ?? containerSystemVersion,
                latestID: ComponentVersionIDs.container,
                latestCheck: latestCheck,
                upgradeCommand: containerUpgradeCommand
            )
        )

        items.append(
            makeItem(
                id: ComponentVersionIDs.containerCompose,
                name: "container-compose",
                sourceDescription: "container-compose version",
                isInstalled: environment.containerComposeAvailable,
                rawCurrentVersion: environment.containerComposeVersion,
                latestID: ComponentVersionIDs.containerCompose,
                latestCheck: latestCheck,
                upgradeCommand: containerComposeUpgradeCommand
            )
        )

        for version in systemVersions where version.appName.caseInsensitiveCompare(ComponentVersionIDs.container) != .orderedSame {
            items.append(
                makeItem(
                    id: ComponentVersionIDs.runtime(version.appName),
                    name: version.appName,
                    sourceDescription: "container system version",
                    isInstalled: true,
                    rawCurrentVersion: version.version,
                    latestID: ComponentVersionIDs.container,
                    latestCheck: latestCheck,
                    upgradeCommand: containerUpgradeCommand
                )
            )
        }

        return items
    }

    private static func makeItem(
        id: String,
        name: String,
        sourceDescription: String,
        isInstalled: Bool,
        rawCurrentVersion: String?,
        latestID: String,
        latestCheck: ComponentLatestVersionCheck?,
        upgradeCommand: String?
    ) -> ComponentVersionItem {
        let currentVersion = ComponentVersionParser.displayVersion(from: rawCurrentVersion)
        let latest = latestCheck?.latestVersion(for: latestID)
        return ComponentVersionItem(
            id: id,
            name: name,
            sourceDescription: sourceDescription,
            isInstalled: isInstalled,
            rawCurrentVersion: rawCurrentVersion?.nilIfBlank,
            currentVersion: currentVersion,
            latestVersion: latest?.version,
            latestVersionSource: latest?.sourceName,
            releaseURL: latest?.releaseURL,
            upgradeCommand: upgradeCommand,
            status: status(
                isInstalled: isInstalled,
                rawCurrentVersion: rawCurrentVersion,
                latest: latest,
                latestCheck: latestCheck
            )
        )
    }

    private static func status(
        isInstalled: Bool,
        rawCurrentVersion: String?,
        latest: ComponentLatestVersion?,
        latestCheck: ComponentLatestVersionCheck?
    ) -> ComponentVersionStatus {
        guard isInstalled else { return .missing }
        guard let latestCheck, latestCheck.hasChecked else {
            return ComponentVersionParser.semanticVersion(from: rawCurrentVersion) == nil ? .unableToCompare : .unchecked
        }
        guard let latest else { return .unableToCompare }
        guard let currentSemantic = ComponentVersionParser.semanticVersion(from: rawCurrentVersion),
              let latestSemantic = ComponentVersionParser.semanticVersion(from: latest.version)
        else {
            return .unableToCompare
        }
        return latestSemantic > currentSemantic ? .updateAvailable : .upToDate
    }
}
