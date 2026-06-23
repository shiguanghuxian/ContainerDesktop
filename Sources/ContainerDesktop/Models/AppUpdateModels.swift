import Foundation

enum AppUpdateArchitecture: String, Codable, Hashable, Sendable {
    case arm64
    case x86_64

    static var current: AppUpdateArchitecture {
        #if arch(arm64)
        .arm64
        #elseif arch(x86_64)
        .x86_64
        #else
        .arm64
        #endif
    }
}

struct SemanticVersion: Comparable, Hashable, Sendable, CustomStringConvertible {
    var components: [Int]
    var original: String

    init?(_ rawValue: String) {
        let trimmed = rawValue.trimmed
        guard !trimmed.isEmpty else { return nil }

        let withoutPrefix = trimmed.hasPrefix("v") || trimmed.hasPrefix("V")
            ? String(trimmed.dropFirst())
            : trimmed
        let core = withoutPrefix.split(separator: "-", maxSplits: 1).first ?? ""
        let parts = core.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty else { return nil }

        var parsed: [Int] = []
        for part in parts {
            let digits = part.prefix { $0.isNumber }
            guard !digits.isEmpty, let value = Int(digits) else { return nil }
            parsed.append(value)
        }
        guard !parsed.isEmpty else { return nil }

        components = parsed
        original = trimmed
    }

    var description: String {
        original
    }

    var normalizedText: String {
        original.hasPrefix("v") || original.hasPrefix("V") ? String(original.dropFirst()) : original
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right {
                return left < right
            }
        }
        return false
    }

    static func == (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }
}

struct AppUpdateAsset: Hashable, Sendable {
    var name: String
    var downloadURL: URL
    var size: Int64
    var sha256: String
    var architecture: AppUpdateArchitecture?

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var normalizedSHA256: String {
        sha256.lowercased().hasPrefix("sha256:")
            ? String(sha256.dropFirst("sha256:".count)).lowercased()
            : sha256.lowercased()
    }
}

struct AppUpdateReleaseNotes: Hashable, Sendable {
    var english: String
    var simplifiedChinese: String

    init(english: String = "", simplifiedChinese: String = "") {
        self.english = english
        self.simplifiedChinese = simplifiedChinese
    }

    init(legacy text: String) {
        if let split = Self.splitLegacyMarkdown(text) {
            self = split
        } else {
            self.init(english: text, simplifiedChinese: "")
        }
    }

    func text(for language: AppLanguage) -> String {
        let englishText = english.trimmed
        let chineseText = simplifiedChinese.trimmed
        if language.resolved == .zhHans, !chineseText.isEmpty {
            return chineseText
        }
        if !englishText.isEmpty {
            return englishText
        }
        return chineseText
    }

    static func resolved(
        english: String?,
        simplifiedChinese: String?,
        legacy: String?
    ) -> AppUpdateReleaseNotes {
        let legacyText = legacy?.nilIfBlank
        let splitLegacy = legacyText.flatMap(splitLegacyMarkdown)
        return AppUpdateReleaseNotes(
            english: english?.nilIfBlank ?? splitLegacy?.english.nilIfBlank ?? legacyText ?? "",
            simplifiedChinese: simplifiedChinese?.nilIfBlank ?? splitLegacy?.simplifiedChinese.nilIfBlank ?? ""
        )
    }

    private static func splitLegacyMarkdown(_ text: String) -> AppUpdateReleaseNotes? {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        guard let chineseIndex = lines.firstIndex(where: { $0.trimmed == "中文" }),
              let englishIndex = lines.firstIndex(where: { $0.trimmed.caseInsensitiveCompare("English") == .orderedSame })
        else {
            return nil
        }

        let firstMarkerIndex = min(chineseIndex, englishIndex)
        let sharedPrefix = lines[..<firstMarkerIndex].joined(separator: "\n").trimmed
        let chineseBody = sectionBody(lines: lines, markerIndex: chineseIndex, otherMarkerIndex: englishIndex)
        let englishBody = sectionBody(lines: lines, markerIndex: englishIndex, otherMarkerIndex: chineseIndex)

        return AppUpdateReleaseNotes(
            english: joinedNotes(prefix: sharedPrefix, body: englishBody),
            simplifiedChinese: joinedNotes(prefix: sharedPrefix, body: chineseBody)
        )
    }

    private static func sectionBody(
        lines: [String],
        markerIndex: Int,
        otherMarkerIndex: Int
    ) -> String {
        let start = markerIndex + 1
        let end = otherMarkerIndex > markerIndex ? otherMarkerIndex : lines.count
        guard start < end else { return "" }
        return lines[start..<end].joined(separator: "\n").trimmed
    }

    private static func joinedNotes(prefix: String, body: String) -> String {
        [prefix.nilIfBlank, body.nilIfBlank]
            .compactMap(\.self)
            .joined(separator: "\n\n")
    }
}

struct AppUpdateRelease: Hashable, Sendable {
    var version: SemanticVersion
    var versionText: String
    var tagName: String
    var title: String
    var publishedAt: Date?
    var releaseNotes: AppUpdateReleaseNotes
    var htmlURL: URL?
    var assets: [AppUpdateAsset]

    init(
        version: SemanticVersion,
        versionText: String,
        tagName: String,
        title: String,
        publishedAt: Date?,
        releaseNotes: AppUpdateReleaseNotes,
        htmlURL: URL?,
        assets: [AppUpdateAsset]
    ) {
        self.version = version
        self.versionText = versionText
        self.tagName = tagName
        self.title = title
        self.publishedAt = publishedAt
        self.releaseNotes = releaseNotes
        self.htmlURL = htmlURL
        self.assets = assets
    }

    init(
        version: SemanticVersion,
        versionText: String,
        tagName: String,
        title: String,
        publishedAt: Date?,
        releaseNotes: String,
        htmlURL: URL?,
        assets: [AppUpdateAsset]
    ) {
        self.init(
            version: version,
            versionText: versionText,
            tagName: tagName,
            title: title,
            publishedAt: publishedAt,
            releaseNotes: AppUpdateReleaseNotes(legacy: releaseNotes),
            htmlURL: htmlURL,
            assets: assets
        )
    }

    func compatibleAsset(for architecture: AppUpdateArchitecture) -> AppUpdateAsset? {
        assets
            .filter { asset in
                guard asset.name.lowercased().hasSuffix(".zip") else { return false }
                if let assetArchitecture = asset.architecture {
                    return assetArchitecture == architecture
                }
                return asset.name.lowercased().contains(architecture.rawValue.lowercased())
            }
            .sorted { left, right in
                let leftScore = assetPreferenceScore(left)
                let rightScore = assetPreferenceScore(right)
                if leftScore != rightScore {
                    return leftScore > rightScore
                }
                return left.name.localizedStandardCompare(right.name) == .orderedAscending
            }
            .first
    }

    private func assetPreferenceScore(_ asset: AppUpdateAsset) -> Int {
        var score = 0
        let name = asset.name.lowercased()
        if name.contains(versionText.lowercased()) {
            score += 20
        }
        if name.contains("containerdesktop") {
            score += 10
        }
        if asset.architecture != nil {
            score += 5
        }
        return score
    }
}

struct AppUpdatePackage: Hashable, Sendable {
    var release: AppUpdateRelease
    var asset: AppUpdateAsset

    var versionText: String {
        release.versionText
    }

    var releaseNotes: String {
        releaseNotes(for: .en)
    }

    func releaseNotes(for language: AppLanguage) -> String {
        release.releaseNotes.text(for: language).trimmed
    }
}

struct AppUpdateDownloadedPackage: Hashable, Sendable {
    var package: AppUpdatePackage
    var fileURL: URL
}

enum AppUpdateCheckResult: Hashable, Sendable {
    case upToDate(AppUpdateRelease)
    case updateAvailable(AppUpdatePackage)
}

enum AppUpdateStatus: Hashable, Sendable {
    case idle
    case checking
    case upToDate(AppUpdateRelease)
    case updateAvailable(AppUpdatePackage)
    case downloading(AppUpdatePackage, progress: Double?)
    case readyToInstall(AppUpdateDownloadedPackage)
    case installing(AppUpdatePackage)
    case failed(String)
}

enum AppUpdateRuntime {
    static let appName = "ContainerDesktop"
    static let bundleIdentifier = AppPaths.bundleIdentifier
    static let executableName = "ContainerDesktop"

    static var releaseVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "debug"
    }

    static var displayVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        if let version, let build {
            return "\(version) (\(build))"
        }
        return version ?? build ?? "Debug"
    }
}
