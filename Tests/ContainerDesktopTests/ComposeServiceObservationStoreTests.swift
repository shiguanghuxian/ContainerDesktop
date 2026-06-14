import Foundation
import Testing
@testable import ContainerDesktop

@Suite("Compose service observation store")
struct ComposeServiceObservationStoreTests {
    @Test("loads service logs and stats for matched containers")
    @MainActor
    func loadsServiceLogsAndStats() async throws {
        let summary = ComposeServiceRuntimeSummary(
            service: ComposeProject.Service(name: "api", image: "example/api:latest"),
            containers: [
                Self.makeContainer(id: "demo-api-1", image: "example/api:latest"),
                Self.makeContainer(id: "demo-api-2", image: "example/api:latest"),
            ]
        )
        let store = ComposeServiceObservationStore(
            logsLoader: { containerID, lines in
                "\(containerID) logs \(lines)"
            },
            statsLoader: { containerIDs in
                containerIDs.map {
                    Self.makeSnapshot(id: $0, memoryUsageBytes: 512, networkRxBytes: 12, numProcesses: 2)
                }
            }
        )

        await store.load(summary: summary, lines: 42)

        #expect(store.selectedServiceName == "api")
        #expect(store.selectedContainerIDs == ["demo-api-1", "demo-api-2"])
        #expect(store.statsSnapshots.map { $0.id } == ["demo-api-1", "demo-api-2"])
        #expect(store.statsSummary?.totalMemoryUsageBytes == 1_024)
        #expect(store.statsSummary?.totalProcesses == 4)
        #expect(store.logsText.contains("[demo-api-1] example/api:latest"))
        #expect(store.logsText.contains("demo-api-2 logs 42"))
        #expect(store.errorMessage == nil)
        #expect(store.lastUpdated != nil)
    }

    @Test("handles services without matched containers")
    @MainActor
    func handlesServicesWithoutContainers() async {
        let summary = ComposeServiceRuntimeSummary(
            service: ComposeProject.Service(name: "web", image: "nginx:latest"),
            containers: []
        )
        let store = ComposeServiceObservationStore(
            logsLoader: { _, _ in "unexpected" },
            statsLoader: { _ in [Self.makeSnapshot(id: "unexpected")] }
        )

        await store.load(summary: summary)

        #expect(store.selectedServiceName == "web")
        #expect(store.selectedContainerIDs.isEmpty)
        #expect(store.statsSnapshots.isEmpty)
        #expect(store.logsText.contains("还没有匹配到容器"))
        #expect(store.errorMessage == nil)
    }

    @Test("loads project logs and stats for matched containers")
    @MainActor
    func loadsProjectLogsAndStats() async {
        let shared = Self.makeContainer(id: "demo-shared-1", image: "example/shared:latest")
        let summaries = [
            ComposeServiceRuntimeSummary(
                service: ComposeProject.Service(name: "web", image: "nginx:latest"),
                containers: [
                    Self.makeContainer(id: "demo-web-1", image: "nginx:latest"),
                    shared,
                ]
            ),
            ComposeServiceRuntimeSummary(
                service: ComposeProject.Service(name: "api", image: "example/api:latest"),
                containers: [
                    Self.makeContainer(id: "demo-api-1", image: "example/api:latest"),
                    shared,
                ]
            ),
        ]
        let store = ComposeServiceObservationStore(
            logsLoader: { containerID, lines in
                "\(containerID) project logs \(lines)"
            },
            statsLoader: { containerIDs in
                containerIDs.map { Self.makeSnapshot(id: $0, memoryUsageBytes: 256, numProcesses: 1) }
            }
        )

        await store.loadProject(projectName: "demo", summaries: summaries, lines: 24)

        #expect(store.selectedServiceName == "demo / all services")
        #expect(store.selectedContainerIDs == ["demo-web-1", "demo-shared-1", "demo-api-1"])
        #expect(store.statsSnapshots.map(\.id) == ["demo-web-1", "demo-shared-1", "demo-api-1"])
        #expect(store.statsSummary?.totalMemoryUsageBytes == 768)
        #expect(store.logsText.contains("[demo-web-1] nginx:latest"))
        #expect(store.logsText.contains("demo-api-1 project logs 24"))
    }

    @Test("handles projects without matched containers")
    @MainActor
    func handlesProjectsWithoutContainers() async {
        let store = ComposeServiceObservationStore(
            logsLoader: { _, _ in "unexpected" },
            statsLoader: { _ in [Self.makeSnapshot(id: "unexpected")] }
        )

        await store.loadProject(projectName: "empty", summaries: [])

        #expect(store.selectedServiceName == "empty / all services")
        #expect(store.selectedContainerIDs.isEmpty)
        #expect(store.statsSnapshots.isEmpty)
        #expect(store.logsText.contains("项目还没有匹配到容器"))
    }

    @Test("keeps logs visible when stats loading fails")
    @MainActor
    func keepsLogsWhenStatsFails() async {
        struct StatsError: LocalizedError {
            var errorDescription: String? { "stats unavailable" }
        }

        let summary = ComposeServiceRuntimeSummary(
            service: ComposeProject.Service(name: "worker", image: "example/worker:latest"),
            containers: [
                Self.makeContainer(id: "demo-worker-1", image: "example/worker:latest"),
            ]
        )
        let store = ComposeServiceObservationStore(
            logsLoader: { containerID, _ in
                "\(containerID) still logged"
            },
            statsLoader: { _ in
                throw StatsError()
            }
        )

        await store.load(summary: summary)

        #expect(store.statsSnapshots.isEmpty)
        #expect(store.logsText.contains("demo-worker-1 still logged"))
        #expect(store.errorMessage?.contains("stats unavailable") == true)
    }

    private static func makeContainer(
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

    private static func makeSnapshot(
        id: String,
        memoryUsageBytes: Int64 = 0,
        networkRxBytes: Int64 = 0,
        numProcesses: Int = 0
    ) -> ContainerStatsSnapshot {
        ContainerStatsSnapshot(
            id: id,
            blockReadBytes: 0,
            blockWriteBytes: 0,
            cpuUsageUsec: 0,
            memoryLimitBytes: 1_073_741_824,
            memoryUsageBytes: memoryUsageBytes,
            networkRxBytes: networkRxBytes,
            networkTxBytes: 0,
            numProcesses: numProcesses
        )
    }
}
