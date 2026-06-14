import Foundation
import Testing
@testable import ContainerDesktop

@Suite("Compose runtime matching")
struct ComposeRuntimeModelsTests {
    @Test("matches services by compose labels")
    func matchesServicesByLabels() throws {
        let project = makeProject(services: [
            makeService(name: "web", image: "nginx:latest"),
            makeService(name: "db", image: "postgres:16"),
        ])
        let container = makeContainer(
            id: "container-a",
            image: "busybox:latest",
            labels: [
                "com.docker.compose.project": "demo",
                "com.docker.compose.service": "web",
            ]
        )

        let summaries = project.runtimeSummaries(containers: [container])
        let web = try #require(summaries.first { $0.service.name == "web" })
        let db = try #require(summaries.first { $0.service.name == "db" })

        #expect(web.containers.map(\.id) == ["container-a"])
        #expect(web.state == .running)
        #expect(db.state == .missing)
    }

    @Test("matches services by project and service tokens in container id")
    func matchesServicesByContainerIDTokens() throws {
        let project = makeProject(services: [
            makeService(name: "api", image: "example/api:latest"),
        ])
        let container = makeContainer(id: "demo-api-1", image: "other:latest")

        let api = try #require(project.runtimeSummaries(containers: [container]).first)

        #expect(api.containers.map(\.id) == ["demo-api-1"])
        #expect(api.containerIDsText == "demo-api-1")
    }

    @Test("uses unique image fallback but skips ambiguous images")
    func usesUniqueImageFallbackOnly() throws {
        let project = makeProject(services: [
            makeService(name: "web", image: "nginx:latest"),
            makeService(name: "api", image: "example/app:latest"),
            makeService(name: "worker", image: "example/app:latest"),
        ])
        let containers = [
            makeContainer(id: "random-1", image: "nginx:latest"),
            makeContainer(id: "random-2", image: "example/app:latest"),
        ]

        let summaries = project.runtimeSummaries(containers: containers)
        let web = try #require(summaries.first { $0.service.name == "web" })
        let api = try #require(summaries.first { $0.service.name == "api" })
        let worker = try #require(summaries.first { $0.service.name == "worker" })

        #expect(web.containers.map(\.id) == ["random-1"])
        #expect(api.containers.isEmpty)
        #expect(worker.containers.isEmpty)
    }

    @Test("builds service container action command previews")
    func buildsServiceContainerActionCommandPreviews() {
        #expect(ComposeServiceContainerAction.start.commandPreview(containerIDs: ["web-1", "api-1"]) == "container start web-1 && container start api-1")
        #expect(ComposeServiceContainerAction.stop.commandPreview(containerIDs: ["web-1"]) == "container stop web-1")
        #expect(ComposeServiceContainerAction.restart.commandPreview(containerIDs: ["web-1"]) == "container stop web-1 && container start web-1")
    }

    @Test("selects a running container for service terminal")
    func selectsRunningContainerForServiceTerminal() {
        let summary = ComposeServiceRuntimeSummary(
            service: makeService(name: "web", image: "nginx:latest"),
            containers: [
                makeContainer(id: "web-stopped", image: "nginx:latest", state: "stopped"),
                makeContainer(id: "web-running", image: "nginx:latest", state: "running"),
            ]
        )

        #expect(summary.runningContainers.map(\.id) == ["web-running"])
        #expect(summary.primaryRunningContainer?.id == "web-running")
    }

    private func makeProject(services: [ComposeProject.Service]) -> ComposeProject {
        ComposeProject(
            path: URL(fileURLWithPath: "/tmp/demo-compose.yml"),
            name: "demo",
            services: services,
            volumes: [],
            networks: [],
            lastModified: Date(timeIntervalSince1970: 0)
        )
    }

    private func makeService(name: String, image: String?) -> ComposeProject.Service {
        ComposeProject.Service(name: name, image: image)
    }

    private func makeContainer(
        id: String,
        image: String,
        state: String = "running",
        labels: [String: String] = [:]
    ) -> ContainerSummary {
        ContainerSummary(
            configuration: .init(
                id: id,
                image: .init(reference: image),
                platform: .init(os: "linux", architecture: "arm64"),
                resources: .init(cpus: 1, memoryInBytes: 1_073_741_824),
                creationDate: nil,
                labels: labels
            ),
            status: .init(state: state, networks: [], startedDate: nil)
        )
    }
}
