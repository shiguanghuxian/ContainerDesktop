import Foundation
import Testing
@testable import ContainerDesktop

private final class RegistryBrowserMockURLProtocol: URLProtocol, @unchecked Sendable {
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

private struct RegistryCredentialResolverStub: RegistryCredentialResolving {
    var credentialsValue: RegistryBrowseCredentials? = nil
    var error: RegistryCredentialResolverStubError? = nil

    func credentials(for server: String, scheme: String) async throws -> RegistryBrowseCredentials? {
        if let error {
            throw error
        }
        return credentialsValue
    }
}

private enum RegistryCredentialResolverStubError: LocalizedError, Sendable {
    case denied

    var errorDescription: String? {
        "无法读取 container 登录凭据，请确认已登录并允许钥匙串访问。"
    }
}

@Suite("Registry browser client", .serialized)
struct RegistryBrowserClientTests {
    @Test("loads registry tags with host port and link cursor")
    func loadsRegistryTagsWithHostPortAndCursor() async throws {
        defer { RegistryBrowserMockURLProtocol.reset() }
        let client = Self.makeClient()

        RegistryBrowserMockURLProtocol.setHandler { request in
            let url = try #require(request.url)
            #expect(url.scheme == "https")
            #expect(url.host == "registry.example.com")
            #expect(url.port == 5000)
            #expect(url.path == "/v2/team/app/tags/list")
            #expect(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.contains(URLQueryItem(name: "n", value: "2")) == true)

            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Link": #"</v2/team/app/tags/list?n=2&last=latest>; rel="next""#]
            )!
            return (response, Data(#"{"name":"team/app","tags":["latest","1.0"]}"#.utf8))
        }

        let page = try await client.registryTags(
            server: "registry.example.com:5000",
            repository: "team/app",
            scheme: "https",
            limit: 2
        )

        #expect(page.items.map(\.name) == ["1.0", "latest"])
        #expect(page.nextCursor == "latest")
        #expect(page.hasNext)
        #expect(RegistryBrowserMockURLProtocol.recordedRequests().count == 1)
    }

    @Test("uses repository bearer token scope")
    func usesRepositoryBearerTokenScope() async throws {
        defer { RegistryBrowserMockURLProtocol.reset() }
        let client = Self.makeClient()

        RegistryBrowserMockURLProtocol.setHandler { request in
            let url = try #require(request.url)
            if url.host == "registry.example.com" {
                if request.value(forHTTPHeaderField: "Authorization") == "Bearer tag-token" {
                    let response = HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )!
                    return (response, Data(#"{"name":"team/app","tags":["latest"]}"#.utf8))
                }

                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: [
                        "WWW-Authenticate": #"Bearer realm="https://auth.example.com/token",service="registry.example.com""#,
                    ]
                )!
                return (response, Data())
            }

            if url.host == "auth.example.com" {
                let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
                #expect(queryItems.contains(URLQueryItem(name: "service", value: "registry.example.com")))
                #expect(queryItems.contains(URLQueryItem(name: "scope", value: "repository:team/app:pull")))
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, Data(#"{"token":"tag-token"}"#.utf8))
            }

            throw URLError(.badServerResponse)
        }

        let page = try await client.registryTags(server: "registry.example.com", repository: "team/app")

        #expect(page.items.map(\.name) == ["latest"])
        let requests = RegistryBrowserMockURLProtocol.recordedRequests()
        #expect(requests.count == 3)
        #expect(requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer tag-token")
    }

    @MainActor
    @Test("store searches private repository without selecting tag details")
    func storeSearchesPrivateRepositoryWithoutSelectingTagDetails() async {
        defer { RegistryBrowserMockURLProtocol.reset() }
        let client = Self.makeClient()
        let credentials = RegistryBrowseCredentials(username: "zuo", password: "token")
        let store = RegistryBrowserStore(
            client: client,
            credentialResolver: RegistryCredentialResolverStub(credentialsValue: credentials)
        )
        store.customRegistryServer = "registry.example.com"
        store.customRepository = "team/app"

        RegistryBrowserMockURLProtocol.setHandler { request in
            let url = try #require(request.url)
            #expect(request.value(forHTTPHeaderField: "Authorization") == credentials.basicAuthorizationHeader)
            #expect(url.path == "/v2/team/app/tags/list")
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(#"{"name":"team/app","tags":["latest","1.0"]}"#.utf8))
        }

        await store.searchCustomRepository()

        #expect(store.customRegistryRepositoryResult?.server == "registry.example.com")
        #expect(store.customRegistryRepositoryResult?.repository == "team/app")
        #expect(store.customRegistryRepositoryResult?.tagCount == 2)
        #expect(store.customRegistryTags.map(\.name) == ["1.0", "latest"])
        #expect(store.selectedCustomRegistryTag == nil)
        #expect(store.errorMessage == nil)
        #expect(RegistryBrowserMockURLProtocol.recordedRequests().count == 1)
    }

    @MainActor
    @Test("store clears private repository result on search failure")
    func storeClearsPrivateRepositoryResultOnSearchFailure() async {
        defer { RegistryBrowserMockURLProtocol.reset() }
        let client = Self.makeClient()
        let store = RegistryBrowserStore(
            client: client,
            credentialResolver: RegistryCredentialResolverStub(error: .denied)
        )
        store.customRegistryServer = "registry.example.com"
        store.customRepository = "team/app"
        store.customRegistryRepositoryResult = RegistryV2RepositoryResult(
            server: "registry.example.com",
            repository: "old/app",
            tagCount: 1,
            hasNextPage: false
        )
        store.customRegistryTags = [
            RegistryImageTag(name: "old", size: nil, updatedAt: nil, digest: nil, mediaType: nil, platforms: []),
        ]

        RegistryBrowserMockURLProtocol.setHandler { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(
                url: url,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        await store.searchCustomRepository()

        #expect(store.customRegistryRepositoryResult == nil)
        #expect(store.customRegistryTags.isEmpty)
        #expect(store.selectedCustomRegistryTag == nil)
        #expect(store.errorMessage?.contains("无法读取 container 登录凭据") == true)
        #expect(store.errorMessage?.contains("请先在 Registries 页面登录当前仓库") == true)
    }

    @MainActor
    @Test("store loads private registry tags with resolved credentials")
    func storeLoadsPrivateRegistryTagsWithResolvedCredentials() async {
        defer { RegistryBrowserMockURLProtocol.reset() }
        let client = Self.makeClient()
        let credentials = RegistryBrowseCredentials(username: "zuo", password: "token")
        let store = RegistryBrowserStore(
            client: client,
            credentialResolver: RegistryCredentialResolverStub(credentialsValue: credentials)
        )
        store.customRegistryServer = "registry.example.com"
        store.customRepository = "team/app"

        RegistryBrowserMockURLProtocol.setHandler { request in
            let url = try #require(request.url)
            #expect(request.value(forHTTPHeaderField: "Authorization") == credentials.basicAuthorizationHeader)
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            if url.path == "/v2/team/app/tags/list" {
                return (response, Data(#"{"name":"team/app","tags":["latest"]}"#.utf8))
            }
            if url.path == "/v2/team/app/manifests/latest" {
                return (response, Data(#"{"schemaVersion":2,"mediaType":"application/vnd.oci.image.manifest.v1+json","layers":[]}"#.utf8))
            }
            throw URLError(.badServerResponse)
        }

        await store.loadCustomRegistryTags()

        #expect(store.customRegistryTags.map(\.name) == ["latest"])
        #expect(store.errorMessage == nil)
    }

    @MainActor
    @Test("store reports keychain lookup failure when registry requires auth")
    func storeReportsKeychainLookupFailureWhenRegistryRequiresAuth() async {
        defer { RegistryBrowserMockURLProtocol.reset() }
        let client = Self.makeClient()
        let store = RegistryBrowserStore(
            client: client,
            credentialResolver: RegistryCredentialResolverStub(error: .denied)
        )
        store.customRegistryServer = "registry.example.com"
        store.customRepository = "team/app"

        RegistryBrowserMockURLProtocol.setHandler { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(
                url: url,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        await store.loadCustomRegistryTags()

        #expect(store.customRegistryTags.isEmpty)
        #expect(store.errorMessage?.contains("无法读取 container 登录凭据") == true)
        #expect(store.errorMessage?.contains("请先在 Registries 页面登录当前仓库") == true)
    }

    private static func makeClient() -> RegistryBrowserClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RegistryBrowserMockURLProtocol.self]
        return RegistryBrowserClient(session: URLSession(configuration: configuration))
    }
}
