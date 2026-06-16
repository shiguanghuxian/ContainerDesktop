import Foundation

protocol ComponentVersionChecking: Sendable {
    func checkLatestVersions() async -> ComponentLatestVersionCheck
}

enum ComponentVersionServiceError: LocalizedError, Hashable {
    case invalidHTTPStatus(Int, String)
    case invalidGitHubRelease
    case invalidHomebrewFormula

    var errorDescription: String? {
        switch self {
        case .invalidHTTPStatus(let statusCode, let detail):
            let suffix = detail.trimmed.isEmpty ? "" : " \(detail)"
            return "Version server returned HTTP \(statusCode).\(suffix)"
        case .invalidGitHubRelease:
            return "The apple/container release response is invalid."
        case .invalidHomebrewFormula:
            return "The container-compose Homebrew formula response is invalid."
        }
    }
}

struct ComponentVersionService: ComponentVersionChecking, @unchecked Sendable {
    static let defaultContainerReleaseURL = URL(string: "https://api.github.com/repos/apple/container/releases/latest")!
    static let defaultContainerComposeFormulaURL = URL(string: "https://formulae.brew.sh/api/formula/container-compose.json")!

    private let containerReleaseURL: URL
    private let containerComposeFormulaURL: URL
    private let session: URLSession

    init(
        containerReleaseURL: URL = Self.defaultContainerReleaseURL,
        containerComposeFormulaURL: URL = Self.defaultContainerComposeFormulaURL,
        session: URLSession = URLSession(configuration: .ephemeral)
    ) {
        self.containerReleaseURL = containerReleaseURL
        self.containerComposeFormulaURL = containerComposeFormulaURL
        self.session = session
    }

    func checkLatestVersions() async -> ComponentLatestVersionCheck {
        var check = ComponentLatestVersionCheck()

        do {
            let latest = try await fetchContainerLatestVersion()
            check.latestVersions[latest.componentID] = latest
        } catch {
            check.errors.append("container: \(error.localizedDescription)")
        }

        do {
            let latest = try await fetchContainerComposeLatestVersion()
            check.latestVersions[latest.componentID] = latest
        } catch {
            check.errors.append("container-compose: \(error.localizedDescription)")
        }

        return check
    }

    func fetchContainerLatestVersion() async throws -> ComponentLatestVersion {
        struct GitHubReleaseResponse: Decodable {
            var tagName: String?
            var htmlURL: URL?

            enum CodingKeys: String, CodingKey {
                case tagName = "tag_name"
                case htmlURL = "html_url"
            }
        }

        let data = try await fetchData(from: containerReleaseURL)
        let release = try JSONDecoder().decode(GitHubReleaseResponse.self, from: data)
        guard let rawVersion = release.tagName?.nilIfBlank,
              let version = ComponentVersionParser.displayVersion(from: rawVersion)
        else {
            throw ComponentVersionServiceError.invalidGitHubRelease
        }
        return ComponentLatestVersion(
            componentID: ComponentVersionIDs.container,
            version: version,
            releaseURL: release.htmlURL ?? URL(string: "https://github.com/apple/container/releases/latest"),
            sourceName: "GitHub releases"
        )
    }

    func fetchContainerComposeLatestVersion() async throws -> ComponentLatestVersion {
        struct HomebrewFormulaResponse: Decodable {
            struct Versions: Decodable {
                var stable: String?
            }

            var versions: Versions
            var homepage: URL?
        }

        let data = try await fetchData(from: containerComposeFormulaURL)
        let formula = try JSONDecoder().decode(HomebrewFormulaResponse.self, from: data)
        guard let rawVersion = formula.versions.stable?.nilIfBlank,
              let version = ComponentVersionParser.displayVersion(from: rawVersion)
        else {
            throw ComponentVersionServiceError.invalidHomebrewFormula
        }
        return ComponentLatestVersion(
            componentID: ComponentVersionIDs.containerCompose,
            version: version,
            releaseURL: formula.homepage ?? URL(string: "https://formulae.brew.sh/formula/container-compose"),
            sourceName: "Homebrew formula"
        )
    }

    private func fetchData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("\(AppUpdateRuntime.appName)/\(AppUpdateRuntime.releaseVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ComponentVersionServiceError.invalidHTTPStatus(-1, "")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ComponentVersionServiceError.invalidHTTPStatus(httpResponse.statusCode, Self.responseMessage(from: data))
        }
        return data
    }

    private static func responseMessage(from data: Data) -> String {
        String(data: data.prefix(240), encoding: .utf8)?.trimmed ?? ""
    }
}
