import Foundation

protocol ComponentVersionChecking: Sendable {
    func checkLatestVersions() async -> ComponentLatestVersionCheck
}

enum ComponentVersionServiceError: LocalizedError, Hashable {
    case invalidHTTPStatus(Int, URL)
    case invalidHomebrewFormula(String)

    var errorDescription: String? {
        switch self {
        case .invalidHTTPStatus(let statusCode, let url):
            return "Version server returned HTTP \(statusCode) for \(url.host ?? url.absoluteString)."
        case .invalidHomebrewFormula(let name):
            return "The \(name) Homebrew formula response is invalid."
        }
    }
}

struct ComponentVersionService: ComponentVersionChecking, @unchecked Sendable {
    static let defaultContainerFormulaURL = URL(string: "https://formulae.brew.sh/api/formula/container.json")!
    static let defaultContainerComposeFormulaURL = URL(string: "https://formulae.brew.sh/api/formula/container-compose.json")!

    private let containerFormulaURL: URL
    private let containerComposeFormulaURL: URL
    private let session: URLSession

    init(
        containerFormulaURL: URL = Self.defaultContainerFormulaURL,
        containerComposeFormulaURL: URL = Self.defaultContainerComposeFormulaURL,
        session: URLSession = URLSession(configuration: .ephemeral)
    ) {
        self.containerFormulaURL = containerFormulaURL
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
        try await fetchHomebrewFormulaLatestVersion(
            componentID: ComponentVersionIDs.container,
            formulaName: "container",
            url: containerFormulaURL,
            fallbackURL: URL(string: "https://formulae.brew.sh/formula/container")
        )
    }

    func fetchContainerComposeLatestVersion() async throws -> ComponentLatestVersion {
        try await fetchHomebrewFormulaLatestVersion(
            componentID: ComponentVersionIDs.containerCompose,
            formulaName: "container-compose",
            url: containerComposeFormulaURL,
            fallbackURL: URL(string: "https://formulae.brew.sh/formula/container-compose")
        )
    }

    private func fetchHomebrewFormulaLatestVersion(
        componentID: String,
        formulaName: String,
        url: URL,
        fallbackURL: URL?
    ) async throws -> ComponentLatestVersion {
        struct HomebrewFormulaResponse: Decodable {
            struct Versions: Decodable {
                var stable: String?
            }

            var versions: Versions
            var homepage: URL?
        }

        let data = try await fetchData(from: url)
        let formula = try JSONDecoder().decode(HomebrewFormulaResponse.self, from: data)
        guard let rawVersion = formula.versions.stable?.nilIfBlank,
              let version = ComponentVersionParser.displayVersion(from: rawVersion)
        else {
            throw ComponentVersionServiceError.invalidHomebrewFormula(formulaName)
        }
        return ComponentLatestVersion(
            componentID: componentID,
            version: version,
            releaseURL: formula.homepage ?? fallbackURL,
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
            throw ComponentVersionServiceError.invalidHTTPStatus(-1, url)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ComponentVersionServiceError.invalidHTTPStatus(httpResponse.statusCode, url)
        }
        return data
    }
}
