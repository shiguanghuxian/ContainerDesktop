import Foundation
import Security
import Testing
@testable import ContainerDesktop

@Suite("Registry models")
struct RegistryModelsTests {
    @Test("decodes current registry list JSON")
    func decodesCurrentRegistryListJSON() throws {
        let json = """
        [
          {
            "creationDate": "2026-06-12T07:36:56Z",
            "id": "registry-1.docker.io",
            "labels": {},
            "modificationDate": "2026-06-12T07:36:56Z",
            "name": "registry-1.docker.io",
            "username": "shiguanghuxian"
          }
        ]
        """

        let registries = try JSONDecoder.containerDesktop.decode([RegistrySummary].self, from: Data(json.utf8))
        #expect(registries.count == 1)
        #expect(registries[0].server == "registry-1.docker.io")
        #expect(registries[0].username == "shiguanghuxian")
        #expect(registries[0].creationDate != nil)
        #expect(registries[0].displayName == "Docker Hub")
        #expect(registries[0].detailServer == "registry-1.docker.io")
    }

    @Test("decodes legacy server JSON")
    func decodesLegacyServerJSON() throws {
        let json = """
        [
          {
            "server": "ghcr.io"
          }
        ]
        """

        let registries = try JSONDecoder.containerDesktop.decode([RegistrySummary].self, from: Data(json.utf8))
        #expect(registries.count == 1)
        #expect(registries[0].server == "ghcr.io")
        #expect(registries[0].username == nil)
        #expect(registries[0].displayName == "ghcr.io")
        #expect(registries[0].detailServer == nil)
    }

    @Test("normalizes Docker Hub display names")
    func normalizesDockerHubDisplayNames() {
        #expect(RegistrySummary(server: "docker.io").displayName == "Docker Hub")
        #expect(RegistrySummary(server: "registry-1.docker.io").displayName == "Docker Hub")
        #expect(RegistrySummary(server: "index.docker.io/v1").displayName == "Docker Hub")
        #expect(RegistrySummary(server: "quay.io").displayName == "quay.io")
    }

    @Test("resolves registry browser context")
    func resolvesRegistryBrowserContext() {
        let dockerHub = RegistrySummary(server: "docker.io")
        let registryV2 = RegistrySummary(server: "ghcr.io")

        #expect(RegistryBrowserContext.context(for: dockerHub) == .dockerHub)
        #expect(RegistryBrowserContext.context(for: registryV2) == .registryV2(server: "ghcr.io"))
        #expect(RegistryBrowserContext.dockerHub.isDockerHub)
        #expect(RegistryBrowserContext.registryV2(server: "ghcr.io").registryServer == "ghcr.io")
        #expect(RegistrySummary(server: "docker.io").registryBrowseServer == "registry-1.docker.io")
    }

    @Test("resolves registry server endpoints")
    func resolvesRegistryServerEndpoints() throws {
        let explicit = try RegistryServerEndpoint.resolve(
            server: "https://registry.example.com:5000/",
            fallbackScheme: "http"
        )
        let implicit = try RegistryServerEndpoint.resolve(
            server: "registry.example.com:5000",
            fallbackScheme: "http"
        )
        let url = try implicit.url(
            path: "/v2/team/app/tags/list",
            queryItems: [URLQueryItem(name: "n", value: "50")]
        )

        #expect(explicit.scheme == "https")
        #expect(explicit.host == "registry.example.com")
        #expect(explicit.port == 5000)
        #expect(explicit.server == "registry.example.com:5000")
        #expect(implicit.scheme == "http")
        #expect(url.absoluteString == "http://registry.example.com:5000/v2/team/app/tags/list?n=50")
    }

    @Test("builds keychain lookup descriptor")
    func buildsKeychainLookupDescriptor() throws {
        let descriptors = try RegistryKeychainCredentialResolver.lookupDescriptors(
            server: "https://registry.example.com:5000/",
            scheme: "http"
        )
        let descriptor = try #require(descriptors.first)

        #expect(descriptors.map(\.securityDomain) == [
            "com.apple.container.registry",
            nil,
            "com.apple.containerization",
        ])
        #expect(descriptor.securityDomain == "com.apple.container.registry")
        #expect(descriptor.server == "registry.example.com:5000")
        #expect(descriptor.itemClass == (kSecClassInternetPassword as String))
    }

    @Test("keychain lookup omits nil security domain")
    func keychainLookupOmitsNilSecurityDomain() throws {
        let descriptors = try RegistryKeychainCredentialResolver.lookupDescriptors(
            server: "registry.example.com",
            scheme: "https"
        )
        let noDomain = try #require(descriptors.first(where: { $0.securityDomain == nil }))
        let query = noDomain.keychainQuery(returnData: false)

        #expect(query[kSecClass as String] as? String == (kSecClassInternetPassword as String))
        #expect(query[kSecAttrServer as String] as? String == "registry.example.com")
        #expect(query[kSecAttrSecurityDomain as String] == nil)
        #expect(query[kSecReturnData as String] as? Bool == false)
    }

    @Test("resolves registry login server input")
    func resolvesRegistryLoginServerInput() {
        let preset = RegistryLoginServerSelection(
            mode: .preset,
            presetServer: " ghcr.io ",
            customServer: "registry.example.com"
        )
        let custom = RegistryLoginServerSelection(
            mode: .custom,
            presetServer: "docker.io",
            customServer: " registry.example.com:5000 "
        )
        let pastedURL = RegistryLoginServerSelection(
            mode: .custom,
            presetServer: "docker.io",
            customServer: "https://registry.example.com/"
        )
        let emptyCustom = RegistryLoginServerSelection(
            mode: .custom,
            presetServer: "docker.io",
            customServer: "   "
        )

        #expect(preset.resolvedServer == "ghcr.io")
        #expect(preset.canSubmit)
        #expect(custom.resolvedServer == "registry.example.com:5000")
        #expect(custom.canSubmit)
        #expect(pastedURL.resolvedServer == "registry.example.com")
        #expect(!emptyCustom.canSubmit)
    }

    @Test("builds tag detail pull references")
    func buildsTagDetailPullReferences() {
        let latest = RegistryImageTag(name: "latest", size: nil, updatedAt: nil, digest: nil, mediaType: nil, platforms: [])
        let version = RegistryImageTag(name: "1.0", size: nil, updatedAt: nil, digest: nil, mediaType: nil, platforms: [])

        let dockerHub = RegistryTagDetailSelection(
            source: .dockerHub,
            title: "Docker Hub Tag Details",
            repository: "nginx",
            tag: latest
        )
        let registryV2 = RegistryTagDetailSelection(
            source: .registryV2,
            title: "Registry v2 Tag Details",
            repository: "ghcr.io/team/app",
            tag: version
        )

        #expect(dockerHub.reference == "nginx:latest")
        #expect(!dockerHub.isRegistryV2)
        #expect(registryV2.reference == "ghcr.io/team/app:1.0")
        #expect(registryV2.isRegistryV2)
    }

    @Test("builds tag list pull references")
    func buildsTagListPullReferences() {
        let latest = RegistryImageTag(name: "latest", size: nil, updatedAt: nil, digest: nil, mediaType: nil, platforms: [])
        let version = RegistryImageTag(name: "1.0", size: nil, updatedAt: nil, digest: nil, mediaType: nil, platforms: [])
        let dockerHub = RegistryTagListSelection(
            source: .dockerHub,
            title: "Docker Hub Tags",
            displayName: "nginx",
            repository: "nginx"
        )
        let registryV2 = RegistryTagListSelection(
            source: .registryV2,
            title: "Registry v2 Tags",
            displayName: "team/app",
            repository: "ghcr.io/team/app"
        )

        #expect(dockerHub.pullReference == "nginx")
        #expect(dockerHub.reference(for: latest) == "nginx:latest")
        #expect(!dockerHub.isRegistryV2)
        #expect(registryV2.pullReference == "ghcr.io/team/app")
        #expect(registryV2.reference(for: version) == "ghcr.io/team/app:1.0")
        #expect(registryV2.isRegistryV2)
    }

    @Test("builds registry v2 repository result references")
    func buildsRegistryV2RepositoryResultReferences() {
        let result = RegistryV2RepositoryResult(
            server: "registry.example.com:5000",
            repository: "team/app",
            tagCount: 2,
            hasNextPage: true
        )

        #expect(result.id == "registry.example.com:5000/team/app")
        #expect(result.pullReference == "registry.example.com:5000/team/app")
        #expect(result.tagCount == 2)
        #expect(result.hasNextPage)
    }

    @Test("tracks registry pagination state")
    func tracksRegistryPaginationState() {
        let page = RegistryPage(
            items: [RegistryImageTag(name: "latest", size: nil, updatedAt: nil, digest: nil, mediaType: nil, platforms: [])],
            totalCount: 100,
            nextCursor: "latest",
            previousCursor: nil,
            page: 2
        )

        #expect(page.hasNext)
        #expect(page.hasPrevious)
        #expect(page.totalCount == 100)
    }

    @Test("formats registry tag detail metadata")
    func formatsRegistryTagDetailMetadata() {
        let tag = RegistryImageTag(
            name: "latest",
            size: 1_024,
            updatedAt: nil,
            digest: "sha256:abc",
            mediaType: "application/vnd.oci.image.index.v1+json",
            platforms: ["linux/amd64", "linux/arm64"]
        )
        let empty = RegistryImageTag(name: "scratch", size: nil, updatedAt: nil, digest: nil, mediaType: nil, platforms: [])

        #expect(tag.digestText == "sha256:abc")
        #expect(tag.mediaTypeText == "OCI index")
        #expect(tag.platformCountText == "2")
        #expect(tag.platformsText == "linux/amd64, linux/arm64")
        #expect(empty.digestText == "—")
        #expect(empty.mediaTypeText == "—")
        #expect(empty.platformCountText == "—")
    }

    @Test("parses registry manifest details")
    func parsesRegistryManifestDetails() throws {
        let json = """
        {
          "schemaVersion": 2,
          "mediaType": "application/vnd.oci.image.index.v1+json",
          "manifests": [
            {
              "mediaType": "application/vnd.oci.image.manifest.v1+json",
              "digest": "sha256:amd64",
              "size": 100,
              "platform": {
                "architecture": "amd64",
                "os": "linux"
              }
            },
            {
              "mediaType": "application/vnd.oci.image.manifest.v1+json",
              "digest": "sha256:arm64",
              "size": 120,
              "platform": {
                "architecture": "arm64",
                "os": "linux",
                "variant": "v8"
              }
            }
          ]
        }
        """

        let details = try RegistryManifestDetails.parse(
            data: Data(json.utf8),
            contentDigest: "sha256:index",
            contentType: "application/vnd.oci.image.index.v1+json; charset=utf-8"
        )
        let tag = RegistryImageTag(
            name: "latest",
            size: nil,
            updatedAt: nil,
            digest: nil,
            mediaType: nil,
            platforms: []
        ).enriched(with: details)

        #expect(details.digest == "sha256:index")
        #expect(details.mediaType == "application/vnd.oci.image.index.v1+json")
        #expect(details.platforms == ["linux/amd64", "linux/arm64/v8"])
        #expect(details.size == nil)
        #expect(tag.digestText == "sha256:index")
        #expect(tag.mediaTypeText == "OCI index")
        #expect(tag.platformsText == "linux/amd64, linux/arm64/v8")
        #expect(tag.sizeDisplay == "—")
    }
}
