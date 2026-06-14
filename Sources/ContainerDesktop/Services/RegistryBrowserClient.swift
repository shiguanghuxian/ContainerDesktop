import Foundation

enum RegistryBrowserError: LocalizedError, Sendable {
    case invalidURL
    case httpStatus(Int)
    case emptyRepository
    case authenticationRequired

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的仓库地址。"
        case .httpStatus(let status):
            return "Registry 请求失败，HTTP \(status)。"
        case .emptyRepository:
            return "仓库名称不能为空。"
        case .authenticationRequired:
            return "Registry 需要认证，请填写用户名和密码或 Token 后重试。"
        }
    }
}

struct RegistryBrowserClient: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchDockerHub(query: String, page: Int = 1, pageSize: Int = 24) async throws -> RegistryPage<RegistryRepositoryResult> {
        var components = URLComponents(string: "https://hub.docker.com/v2/search/repositories/")
        components?.queryItems = [
            URLQueryItem(name: "query", value: query.trimmed),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "page_size", value: "\(pageSize)"),
        ]
        guard let url = components?.url else { throw RegistryBrowserError.invalidURL }
        let response = try await fetch(DockerHubSearchResponse.self, from: url)
        return RegistryPage(
            items: response.results.map(\.repositoryResult),
            totalCount: response.count,
            nextCursor: response.next,
            previousCursor: response.previous,
            page: page
        )
    }

    func dockerHubTags(repository: String, page: Int = 1, pageSize: Int = 30) async throws -> RegistryPage<RegistryImageTag> {
        let normalized = normalizedDockerHubRepository(repository)
        guard !normalized.isEmpty else { throw RegistryBrowserError.emptyRepository }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "hub.docker.com"
        components.path = "/v2/repositories/\(normalized)/tags"
        components.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "page_size", value: "\(pageSize)"),
        ]
        guard let url = components.url else { throw RegistryBrowserError.invalidURL }
        let response = try await fetch(DockerHubTagsResponse.self, from: url)
        return RegistryPage(
            items: response.results.map(\.imageTag),
            totalCount: response.count,
            nextCursor: response.next,
            previousCursor: response.previous,
            page: page
        )
    }

    func registryTags(
        server: String,
        repository: String,
        scheme: String = "https",
        credentials: RegistryBrowseCredentials? = nil,
        limit: Int = 50,
        last: String? = nil
    ) async throws -> RegistryPage<RegistryImageTag> {
        let trimmedServer = server.trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let trimmedRepository = repository.trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmedServer.isEmpty, !trimmedRepository.isEmpty else { throw RegistryBrowserError.emptyRepository }

        var components = URLComponents()
        components.scheme = scheme.nilIfBlank ?? "https"
        components.host = trimmedServer
        components.path = "/v2/\(trimmedRepository)/tags/list"
        var queryItems = [URLQueryItem(name: "n", value: "\(limit)")]
        if let last = last?.nilIfBlank {
            queryItems.append(URLQueryItem(name: "last", value: last))
        }
        components.queryItems = queryItems
        guard let url = components.url else { throw RegistryBrowserError.invalidURL }
        let result = try await fetchRegistryTags(
            from: url,
            repository: trimmedRepository,
            credentials: credentials
        )
        let items = (result.response.tags ?? []).sorted().map {
            RegistryImageTag(name: $0, size: nil, updatedAt: nil, digest: nil, mediaType: nil, platforms: [])
        }
        let nextCursor = result.hasNext ? items.last?.name : nil
        return RegistryPage(
            items: items,
            totalCount: nil,
            nextCursor: nextCursor,
            previousCursor: last,
            page: 1
        )
    }

    func registryManifest(
        server: String,
        repository: String,
        reference: String,
        scheme: String = "https",
        credentials: RegistryBrowseCredentials? = nil
    ) async throws -> RegistryManifestDetails {
        let trimmedServer = server.trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let trimmedRepository = repository.trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let trimmedReference = reference.trimmed
        guard !trimmedServer.isEmpty, !trimmedRepository.isEmpty, !trimmedReference.isEmpty else {
            throw RegistryBrowserError.emptyRepository
        }

        var components = URLComponents()
        components.scheme = scheme.nilIfBlank ?? "https"
        components.host = trimmedServer
        components.path = "/v2/\(trimmedRepository)/manifests/\(trimmedReference)"
        guard let url = components.url else { throw RegistryBrowserError.invalidURL }

        let result = try await fetchRegistryResource(
            from: url,
            repository: trimmedRepository,
            credentials: credentials,
            acceptedMediaTypes: RegistryManifestDetails.acceptedMediaTypes
        )
        return try RegistryManifestDetails.parse(
            data: result.data,
            contentDigest: result.response?.value(forHTTPHeaderField: "Docker-Content-Digest"),
            contentType: result.response?.value(forHTTPHeaderField: "Content-Type")
        )
    }

    private func fetch<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw RegistryBrowserError.httpStatus(httpResponse.statusCode)
        }
        return try JSONDecoder.containerDesktop.decode(T.self, from: data)
    }

    private func fetchRegistryTags(
        from url: URL,
        repository: String,
        credentials: RegistryBrowseCredentials?
    ) async throws -> (response: RegistryTagsResponse, hasNext: Bool) {
        let result = try await fetchRegistryResource(
            from: url,
            repository: repository,
            credentials: credentials
        )
        let decoded = try JSONDecoder.containerDesktop.decode(RegistryTagsResponse.self, from: result.data)
        return (decoded, result.response?.value(forHTTPHeaderField: "Link") != nil)
    }

    private func fetchRegistryResource(
        from url: URL,
        repository: String,
        credentials: RegistryBrowseCredentials?,
        acceptedMediaTypes: [String] = []
    ) async throws -> (data: Data, response: HTTPURLResponse?) {
        var request = URLRequest(url: url)
        if let header = credentials?.basicAuthorizationHeader {
            request.setValue(header, forHTTPHeaderField: "Authorization")
        }
        if !acceptedMediaTypes.isEmpty {
            request.setValue(acceptedMediaTypes.joined(separator: ", "), forHTTPHeaderField: "Accept")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            return (data, nil)
        }

        if (200..<300).contains(httpResponse.statusCode) {
            return (data, httpResponse)
        }

        guard httpResponse.statusCode == 401,
              let challenge = httpResponse.value(forHTTPHeaderField: "WWW-Authenticate"),
              let tokenURL = bearerTokenURL(from: challenge, repository: repository) else {
            if httpResponse.statusCode == 401 { throw RegistryBrowserError.authenticationRequired }
            throw RegistryBrowserError.httpStatus(httpResponse.statusCode)
        }

        var tokenRequest = URLRequest(url: tokenURL)
        if let header = credentials?.basicAuthorizationHeader {
            tokenRequest.setValue(header, forHTTPHeaderField: "Authorization")
        }
        let (tokenData, tokenResponse) = try await session.data(for: tokenRequest)
        if let tokenHTTPResponse = tokenResponse as? HTTPURLResponse,
           !(200..<300).contains(tokenHTTPResponse.statusCode) {
            if tokenHTTPResponse.statusCode == 401 { throw RegistryBrowserError.authenticationRequired }
            throw RegistryBrowserError.httpStatus(tokenHTTPResponse.statusCode)
        }
        let token = try JSONDecoder.containerDesktop.decode(RegistryBearerTokenResponse.self, from: tokenData).resolvedToken
        var retry = URLRequest(url: url)
        retry.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if !acceptedMediaTypes.isEmpty {
            retry.setValue(acceptedMediaTypes.joined(separator: ", "), forHTTPHeaderField: "Accept")
        }
        let (retryData, retryResponse) = try await session.data(for: retry)
        if let retryHTTPResponse = retryResponse as? HTTPURLResponse,
           !(200..<300).contains(retryHTTPResponse.statusCode) {
            if retryHTTPResponse.statusCode == 401 { throw RegistryBrowserError.authenticationRequired }
            throw RegistryBrowserError.httpStatus(retryHTTPResponse.statusCode)
        }
        return (retryData, retryResponse as? HTTPURLResponse)
    }

    private func bearerTokenURL(from challenge: String, repository: String) -> URL? {
        guard challenge.localizedCaseInsensitiveContains("Bearer") else { return nil }
        let parameters = parseAuthenticateParameters(challenge)
        guard let realm = parameters["realm"],
              var components = URLComponents(string: realm) else {
            return nil
        }

        var queryItems = components.queryItems ?? []
        if let service = parameters["service"] {
            queryItems.append(URLQueryItem(name: "service", value: service))
        }
        let scope = parameters["scope"] ?? "repository:\(repository):pull"
        queryItems.append(URLQueryItem(name: "scope", value: scope))
        components.queryItems = queryItems
        return components.url
    }

    private func parseAuthenticateParameters(_ challenge: String) -> [String: String] {
        let raw = challenge.replacingOccurrences(of: "Bearer", with: "", options: [.caseInsensitive])
        var result: [String: String] = [:]
        for item in raw.split(separator: ",") {
            let parts = item.split(separator: "=", maxSplits: 1).map {
                String($0).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard parts.count == 2 else { continue }
            result[parts[0].lowercased()] = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
        return result
    }

    private func normalizedDockerHubRepository(_ repository: String) -> String {
        let value = repository.trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !value.isEmpty else { return "" }
        if value.contains("/") { return value }
        return "library/\(value)"
    }
}

private struct DockerHubSearchResponse: Decodable {
    var count: Int?
    var next: String?
    var previous: String?
    var results: [DockerHubRepositoryResponse]
}

private struct DockerHubRepositoryResponse: Decodable {
    var repoName: String
    var shortDescription: String?
    var starCount: Int?
    var pullCount: Int?
    var isOfficial: Bool?

    enum CodingKeys: String, CodingKey {
        case repoName = "repo_name"
        case shortDescription = "short_description"
        case starCount = "star_count"
        case pullCount = "pull_count"
        case isOfficial = "is_official"
    }

    var repositoryResult: RegistryRepositoryResult {
        RegistryRepositoryResult(
            name: repoName,
            description: shortDescription ?? "",
            stars: starCount ?? 0,
            pulls: pullCount ?? 0,
            isOfficial: isOfficial ?? false
        )
    }
}

private struct DockerHubTagsResponse: Decodable {
    var count: Int?
    var next: String?
    var previous: String?
    var results: [DockerHubTagResponse]
}

private struct DockerHubTagResponse: Decodable {
    struct Image: Decodable {
        var architecture: String?
        var os: String?
        var digest: String?
        var size: Int64?

        var platformText: String? {
            let parts = [os, architecture].compactMap { $0?.nilIfBlank }
            return parts.isEmpty ? nil : parts.joined(separator: "/")
        }
    }

    var name: String
    var fullSize: Int64?
    var lastUpdated: Date?
    var images: [Image]?

    enum CodingKeys: String, CodingKey {
        case name
        case fullSize = "full_size"
        case lastUpdated = "last_updated"
        case images
    }

    var imageTag: RegistryImageTag {
        RegistryImageTag(
            name: name,
            size: fullSize ?? images?.compactMap(\.size).max(),
            updatedAt: lastUpdated,
            digest: images?.compactMap(\.digest).first,
            mediaType: nil,
            platforms: Array(Set(images?.compactMap(\.platformText) ?? [])).sorted()
        )
    }
}

private struct RegistryTagsResponse: Decodable {
    var name: String
    var tags: [String]?
}

private struct RegistryBearerTokenResponse: Decodable {
    var token: String?
    var accessToken: String?

    enum CodingKeys: String, CodingKey {
        case token
        case accessToken = "access_token"
    }

    var resolvedToken: String {
        token ?? accessToken ?? ""
    }
}
