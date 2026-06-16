import Foundation
import Testing
@testable import ContainerDesktop

private final class ComponentVersionMockURLProtocol: URLProtocol, @unchecked Sendable {
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

@Suite("Component versions", .serialized)
struct ComponentVersionTests {
    @Test("parses semantic versions from CLI output")
    func parsesSemanticVersionsFromCLIOutput() {
        #expect(ComponentVersionParser.semanticVersionText(from: "container CLI version 1.0.0 (build: release, commit: ee848e3)") == "1.0.0")
        #expect(ComponentVersionParser.semanticVersionText(from: "container-compose version 1.0.0") == "1.0.0")
        #expect(ComponentVersionParser.semanticVersionText(from: "v1.2.3") == "1.2.3")
        #expect(ComponentVersionParser.semanticVersionText(from: "not a version") == nil)
    }

    @Test("builds local component status before latest check")
    func buildsLocalComponentStatusBeforeLatestCheck() {
        let items = ComponentVersionCatalog.makeItems(
            environment: environment(container: true, compose: true),
            systemVersions: [
                SystemVersionEntry(appName: "container", buildType: "release", commit: "abc", version: "1.0.0"),
                SystemVersionEntry(appName: "container-apiserver", buildType: "release", commit: "abc", version: "container-apiserver version 1.0.0 (build: release)")
            ],
            latestCheck: nil
        )

        #expect(items.map(\.id) == [
            ComponentVersionIDs.container,
            ComponentVersionIDs.containerCompose,
            ComponentVersionIDs.runtime("container-apiserver"),
        ])
        #expect(items.first { $0.id == ComponentVersionIDs.container }?.currentVersion == "1.0.0")
        #expect(items.first { $0.id == ComponentVersionIDs.containerCompose }?.currentVersion == "1.0.0")
        #expect(items.first { $0.id == ComponentVersionIDs.runtime("container-apiserver") }?.currentVersion == "1.0.0")
        #expect(items.allSatisfy { $0.status == .unchecked })
    }

    @Test("marks update availability and missing components")
    func marksUpdateAvailabilityAndMissingComponents() {
        let check = ComponentLatestVersionCheck(
            latestVersions: [
                ComponentVersionIDs.container: ComponentLatestVersion(
                    componentID: ComponentVersionIDs.container,
                    version: "1.1.0",
                    releaseURL: URL(string: "https://formulae.brew.sh/formula/container"),
                    sourceName: "Homebrew formula"
                ),
                ComponentVersionIDs.containerCompose: ComponentLatestVersion(
                    componentID: ComponentVersionIDs.containerCompose,
                    version: "1.0.0",
                    releaseURL: URL(string: "https://formulae.brew.sh/formula/container-compose"),
                    sourceName: "Homebrew formula"
                ),
            ],
            errors: []
        )
        let items = ComponentVersionCatalog.makeItems(
            environment: environment(container: true, compose: false),
            systemVersions: [
                SystemVersionEntry(appName: "container-apiserver", buildType: "release", commit: "abc", version: "1.0.0")
            ],
            latestCheck: check
        )

        #expect(items.first { $0.id == ComponentVersionIDs.container }?.status == .updateAvailable)
        #expect(items.first { $0.id == ComponentVersionIDs.containerCompose }?.status == .missing)
        #expect(items.first { $0.id == ComponentVersionIDs.runtime("container-apiserver") }?.status == .updateAvailable)
    }

    @Test("marks unable to compare when current version is not semantic")
    func marksUnableToCompareWhenCurrentVersionIsNotSemantic() {
        let check = ComponentLatestVersionCheck(
            latestVersions: [
                ComponentVersionIDs.container: ComponentLatestVersion(
                    componentID: ComponentVersionIDs.container,
                    version: "1.0.0",
                    releaseURL: nil,
                    sourceName: "Homebrew formula"
                )
            ],
            errors: []
        )
        let items = ComponentVersionCatalog.makeItems(
            environment: environment(container: true, compose: true, containerVersion: "dev build", composeVersion: "container-compose version 1.0.0"),
            systemVersions: [],
            latestCheck: check
        )

        #expect(items.first { $0.id == ComponentVersionIDs.container }?.status == .unableToCompare)
        #expect(items.first { $0.id == ComponentVersionIDs.containerCompose }?.status == .unableToCompare)
    }

    @Test("service decodes Homebrew formula latest versions")
    func serviceDecodesLatestVersions() async throws {
        defer { ComponentVersionMockURLProtocol.reset() }
        ComponentVersionMockURLProtocol.setHandler { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if request.url?.lastPathComponent == "container.json" {
                return (response, Data(#"{"versions":{"stable":"1.2.0"},"homepage":"https://apple.github.io/container/documentation/"}"#.utf8))
            }
            return (response, Data(#"{"versions":{"stable":"1.3.0"},"homepage":"https://github.com/mcrich23/container-compose"}"#.utf8))
        }

        let check = await Self.makeService().checkLatestVersions()

        #expect(check.errors.isEmpty)
        #expect(check.latestVersion(for: ComponentVersionIDs.container)?.version == "1.2.0")
        #expect(check.latestVersion(for: ComponentVersionIDs.containerCompose)?.version == "1.3.0")
        #expect(check.latestVersion(for: ComponentVersionIDs.container)?.sourceName == "Homebrew formula")
        #expect(check.latestVersion(for: ComponentVersionIDs.containerCompose)?.sourceName == "Homebrew formula")
    }

    @Test("service preserves partial results when one source fails")
    func servicePreservesPartialResultsWhenOneSourceFails() async throws {
        defer { ComponentVersionMockURLProtocol.reset() }
        ComponentVersionMockURLProtocol.setHandler { request in
            if request.url?.lastPathComponent == "container.json" {
                let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
                return (response, Data(#"{"message":"API rate limit exceeded for 127.0.0.1. Documentation URL: https://docs.github.com/rest/overview/resources-in-the-rest-api#rate-limiting"}"#.utf8))
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"versions":{"stable":"1.3.0"},"homepage":"https://github.com/mcrich23/container-compose"}"#.utf8))
        }

        let check = await Self.makeService().checkLatestVersions()

        #expect(check.latestVersion(for: ComponentVersionIDs.container) == nil)
        #expect(check.latestVersion(for: ComponentVersionIDs.containerCompose)?.version == "1.3.0")
        #expect(check.errorMessage?.contains("container:") == true)
        #expect(check.errorMessage?.contains("API rate limit exceeded") == false)
        #expect(check.errorMessage?.contains(#""message""#) == false)
    }

    private static func makeService() -> ComponentVersionService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ComponentVersionMockURLProtocol.self]
        return ComponentVersionService(
            containerFormulaURL: URL(string: "https://brew.test/api/formula/container.json")!,
            containerComposeFormulaURL: URL(string: "https://brew.test/api/formula/container-compose.json")!,
            session: URLSession(configuration: configuration)
        )
    }

    private func environment(
        container: Bool,
        compose: Bool,
        containerVersion: String? = "container CLI version 1.0.0 (build: release)",
        composeVersion: String? = "container-compose version 1.0.0"
    ) -> EnvironmentProbe {
        EnvironmentProbe(
            macOSVersion: "26.0",
            architecture: "arm64",
            containerAvailable: container,
            containerComposeAvailable: compose,
            containerVersion: container ? containerVersion : nil,
            containerComposeVersion: compose ? composeVersion : nil,
            systemRunning: container,
            systemVersion: container ? "running" : nil,
            errorMessage: nil
        )
    }
}
