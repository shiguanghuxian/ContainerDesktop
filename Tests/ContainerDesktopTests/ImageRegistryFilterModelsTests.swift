import Foundation
import Testing
@testable import ContainerDesktop

@Suite("Image registry filter models")
struct ImageRegistryFilterModelsTests {
    @Test("resolves Docker Hub and private registry identities")
    func resolvesRegistryIdentities() {
        #expect(image("alpine:latest").registryIdentity.id == ImageRegistryIdentity.dockerHubKey)
        #expect(image("library/nginx:latest").registryIdentity.displayName == "Docker Hub")
        #expect(image("docker.io/library/nginx:latest").registryIdentity.id == ImageRegistryIdentity.dockerHubKey)
        #expect(image("registry-1.docker.io/library/nginx@sha256:abc").registryIdentity.displayName == "Docker Hub")

        #expect(image("ghcr.io/org/app:1").registryIdentity.server == "ghcr.io")
        #expect(image("registry.example.com:5000/team/app:latest").registryIdentity.server == "registry.example.com:5000")
        #expect(image("localhost/app:latest").registryIdentity.server == "localhost")
        #expect(image("quay.io/org/app").registryIdentity.server == "quay.io")
        #expect(image("team/app@sha256:abc").registryIdentity.id == ImageRegistryIdentity.dockerHubKey)
    }

    @Test("parses image reference parts")
    func parsesImageReferenceParts() {
        let implicit = ImageReferenceParts.parse("alpine:latest")
        let explicit = ImageReferenceParts.parse("docker.io/library/alpine:3.20")
        let privateRegistry = ImageReferenceParts.parse("registry.example.com:5000/team/app:1.0")
        let digest = ImageReferenceParts.parse("ghcr.io/team/app@sha256:abc")

        #expect(implicit.registryIdentity.id == ImageRegistryIdentity.dockerHubKey)
        #expect(implicit.repository == "library/alpine")
        #expect(implicit.tag == "latest")
        #expect(implicit.repositoryKey == explicit.repositoryKey)
        #expect(explicit.tag == "3.20")
        #expect(privateRegistry.registryIdentity.server == "registry.example.com:5000")
        #expect(privateRegistry.repository == "team/app")
        #expect(privateRegistry.tag == "1.0")
        #expect(digest.digest == "sha256:abc")
        #expect(digest.tag == nil)
        #expect(digest.tagDisplayName == "sha256:abc")
    }

    @Test("groups images by registry and repository")
    func groupsImagesByRegistryAndRepository() throws {
        let images = [
            image("alpine:latest", digest: "sha256:a", created: 100, size: 10),
            image("docker.io/library/alpine:3.20", digest: "sha256:a", created: 90, size: 10),
            image("docker.io/library/alpine:3.19", digest: "sha256:b", created: 80, size: 20),
            image("ghcr.io/team/app:latest", digest: "sha256:c", created: 110, size: 30),
            image("ghcr.io/team/other:latest", digest: "sha256:d", created: 120, size: 40),
        ]

        let groups = ImageRepositoryGroup.make(images: images)
        let alpine = try #require(groups.first { $0.repository == "library/alpine" })
        let app = try #require(groups.first { $0.displayName == "ghcr.io/team/app" })

        #expect(groups.count == 3)
        #expect(alpine.references == [
            "alpine:latest",
            "docker.io/library/alpine:3.19",
            "docker.io/library/alpine:3.20",
        ])
        #expect(alpine.primaryImage.reference == "alpine:latest")
        #expect(alpine.sizeDisplay != "—")
        #expect(app.references == ["ghcr.io/team/app:latest"])
    }

    @Test("builds list entries for display modes")
    func buildsListEntriesForDisplayModes() {
        let images = [
            image("alpine:latest"),
            image("docker.io/library/alpine:3.20"),
        ]

        #expect(ImageListEntry.make(images: images, displayMode: .tags).count == 2)
        #expect(ImageListEntry.make(images: images, displayMode: .repositories).count == 1)
    }

    @Test("builds filter options from local images and registry logins")
    func buildsFilterOptions() {
        let options = ImageRegistryFilterOptions.make(
            images: [
                image("alpine:latest"),
                image("docker.io/library/busybox:latest"),
                image("ghcr.io/org/app:latest"),
                image("registry.example.com:5000/team/app:latest"),
            ],
            registries: [
                RegistrySummary(server: "registry-1.docker.io"),
                RegistrySummary(server: "quay.io"),
                RegistrySummary(server: "https://registry.example.com:5000/"),
            ]
        )

        #expect(options.first?.id == ImageRegistryIdentity.dockerHubKey)
        #expect(Set(options.map(\.id)) == [
            "docker.io",
            "ghcr.io",
            "quay.io",
            "registry.example.com:5000",
        ])
        #expect(options.filter { $0.id == ImageRegistryIdentity.dockerHubKey }.count == 1)
    }

    @Test("keeps logged registries without local images")
    func keepsLoggedRegistriesWithoutLocalImages() {
        let options = ImageRegistryFilterOptions.make(
            images: [],
            registries: [RegistrySummary(server: "registry.internal:5000")]
        )

        #expect(options.map(\.id) == ["registry.internal:5000"])
        #expect(options.first?.displayName == "registry.internal:5000")
    }

    private func image(
        _ reference: String,
        digest: String = "sha256:test",
        created: TimeInterval? = nil,
        size: Int64 = 0
    ) -> ImageSummary {
        ImageSummary(
            configuration: .init(
                name: reference,
                creationDate: created.map { Date(timeIntervalSince1970: $0) },
                descriptor: .init(digest: digest)
            ),
            variants: size > 0
                ? [
                    .init(
                        platform: .init(os: "linux", architecture: "arm64", variant: nil),
                        digest: digest,
                        size: size,
                        config: nil
                    ),
                ]
                : []
        )
    }
}
