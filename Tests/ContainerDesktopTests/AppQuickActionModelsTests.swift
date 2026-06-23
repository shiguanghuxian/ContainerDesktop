import Foundation
import Testing
@testable import ContainerDesktop

@Suite("App quick actions")
struct AppQuickActionModelsTests {
    @Test("builder exposes grouped navigation copy execute and confirm actions")
    @MainActor
    func builderExposesGroupedActions() {
        let runtimeStore = RuntimeStore()
        runtimeStore.environment.systemRunning = true
        let container = Self.makeContainer(
            id: "web-1",
            imageName: "docker.io/library/nginx:latest",
            state: "running",
            ipv4Address: "192.168.64.10"
        )
        runtimeStore.containers = [container]
        runtimeStore.images = [Self.makeImage(reference: "docker.io/library/nginx:latest")]
        runtimeStore.volumes = [Self.makeVolume(name: "web-data")]
        runtimeStore.containerBrowserPortTargets[container.id] = ContainerBrowserPortTarget.targets(
            from: """
            {
              "configuration": {
                "publishedPorts": [
                  { "hostIP": "0.0.0.0", "hostPort": 8080, "containerPort": 80, "protocol": "tcp" }
                ]
              }
            }
            """,
            container: container
        )

        let composeStore = ComposeProjectStore()
        composeStore.projects = [
            ComposeProject(
                path: URL(fileURLWithPath: "/tmp/demo/compose.yaml"),
                name: "demo",
                services: [
                    .init(name: "web", image: container.imageName),
                ],
                volumes: [],
                networks: [],
                lastModified: Date(timeIntervalSince1970: 1_700_000_000)
            ),
        ]

        let operationStore = AppOperationStore(persistenceURL: Self.temporaryURL())
        _ = operationStore.start(
            domain: .container,
            title: "Restart web",
            target: container.id,
            commandPreview: "container stop web-1 && container start web-1"
        )

        let actions = AppQuickActionBuilder.make(
            language: .zhHans,
            runtimeStore: runtimeStore,
            composeStore: composeStore,
            operationStore: operationStore
        )

        #expect(actions.contains { $0.group == .pages && $0.kind == .navigate })
        #expect(actions.contains { $0.group == .resources && $0.target == .navigate(.resource(.container(id: "web-1", tab: nil))) })
        #expect(actions.contains { $0.kind == .openURL && $0.target == .openURL("http://127.0.0.1:8080") })
        #expect(actions.contains { $0.kind == .copyText && $0.subtitle.contains("127.0.0.1:8080") })
        #expect(actions.contains { $0.kind == .execute && $0.target == .runContainerImage("docker.io/library/nginx:latest") })
        #expect(actions.contains { $0.kind == .execute && $0.target == .pullImage("docker.io/library/nginx:latest") })
        #expect(actions.contains { $0.kind == .execute && $0.target == .tagImage("docker.io/library/nginx:latest") })
        #expect(actions.contains { $0.kind == .execute && $0.target == .pushImage("docker.io/library/nginx:latest") })
        #expect(actions.contains { $0.target == .navigate(.resource(.imageTasks)) })
        #expect(actions.contains { $0.target == .navigate(.resource(.composeTasks)) })
        #expect(actions.contains { $0.kind == .confirmDestructive && $0.target == .compose(.down, projectID: "/tmp/demo/compose.yaml", serviceName: nil) })
        #expect(actions.contains { $0.group == .recentOperations && $0.kind == .copyText })
    }

    @Test("search ranks matches and keeps result limit")
    func searchRanksMatchesAndKeepsLimit() {
        let actions = (0..<40).map { index in
            AppQuickAction(
                id: "action-\(index)",
                title: index == 7 ? "PostgreSQL connection" : "Other \(index)",
                subtitle: "demo",
                systemImage: "terminal",
                group: index.isMultiple(of: 2) ? .actions : .resources,
                kind: .execute,
                target: .refreshAll,
                keywords: index == 7 ? ["postgres", "database"] : ["misc"],
                rank: index == 7 ? 10 : 100 + index
            )
        }

        let filtered = AppQuickActionSearch.filter(actions, query: "postgres", limit: 3)

        #expect(filtered.map(\.id) == ["action-7"])
        #expect(AppQuickActionSearch.filter(actions, query: "", limit: 5).count == 5)
    }

    private static func makeContainer(
        id: String,
        imageName: String,
        state: String,
        ipv4Address: String
    ) -> ContainerSummary {
        ContainerSummary(
            configuration: .init(
                id: id,
                image: .init(reference: imageName),
                platform: .init(os: "linux", architecture: "arm64"),
                resources: .init(cpus: 2, memoryInBytes: 1_073_741_824),
                creationDate: nil,
                labels: [:]
            ),
            status: .init(
                state: state,
                networks: [.init(ipv4Address: ipv4Address)],
                startedDate: nil
            )
        )
    }

    private static func makeImage(reference: String) -> ImageSummary {
        ImageSummary(
            configuration: .init(
                name: reference,
                creationDate: Date(timeIntervalSince1970: 1_700_000_000),
                descriptor: .init(digest: "sha256:abcdef")
            ),
            variants: [
                .init(
                    platform: .init(os: "linux", architecture: "arm64", variant: nil),
                    digest: "sha256:variant",
                    size: 12_345,
                    config: nil
                ),
            ]
        )
    }

    private static func makeVolume(name: String) -> VolumeSummary {
        VolumeSummary(configuration: .init(
            name: name,
            driver: "local",
            format: "apfs",
            source: "/var/lib/container/volumes/\(name)",
            creationDate: Date(timeIntervalSince1970: 1_700_000_000),
            labels: [:],
            options: [:],
            sizeInBytes: 1_024
        ))
    }

    private static func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "containerdesktop-quick-actions-\(UUID().uuidString).json")
    }
}
