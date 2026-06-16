import Foundation
import Testing
@testable import ContainerDesktop

@Suite("Observability models")
struct ObservabilityModelsTests {
    @Test("summarizes global stats snapshots")
    func summarizesGlobalStatsSnapshots() {
        let snapshots = [
            makeSnapshot(
                id: "b",
                blockReadBytes: 100,
                blockWriteBytes: 200,
                cpuUsageUsec: 10,
                memoryLimitBytes: 1_000,
                memoryUsageBytes: 400,
                networkRxBytes: 20,
                networkTxBytes: 30,
                numProcesses: 2
            ),
            makeSnapshot(
                id: "a",
                blockReadBytes: 300,
                blockWriteBytes: 400,
                cpuUsageUsec: 20,
                memoryLimitBytes: 2_000,
                memoryUsageBytes: 600,
                networkRxBytes: 40,
                networkTxBytes: 50,
                numProcesses: 3
            ),
        ]

        let summary = ObservabilityStatsSummary(snapshots: snapshots)

        #expect(summary.containerCount == 2)
        #expect(summary.totalMemoryUsageBytes == 1_000)
        #expect(summary.totalMemoryLimitBytes == 3_000)
        #expect(summary.totalNetworkRxBytes == 60)
        #expect(summary.totalNetworkTxBytes == 80)
        #expect(summary.totalBlockReadBytes == 400)
        #expect(summary.totalBlockWriteBytes == 600)
        #expect(summary.totalProcesses == 5)
    }

    @Test("sorts stats snapshots by selected metric")
    func sortsStatsSnapshotsBySelectedMetric() {
        let snapshots = [
            makeSnapshot(id: "c", memoryUsageBytes: 20, networkRxBytes: 1, networkTxBytes: 1, numProcesses: 2),
            makeSnapshot(id: "a", memoryUsageBytes: 20, networkRxBytes: 20, networkTxBytes: 10, numProcesses: 5),
            makeSnapshot(id: "b", memoryUsageBytes: 40, networkRxBytes: 2, networkTxBytes: 2, numProcesses: 1),
        ]

        #expect(snapshots.sortedForObservability(by: .memory).map(\.id) == ["b", "a", "c"])
        #expect(snapshots.sortedForObservability(by: .network).map(\.id) == ["a", "b", "c"])
        #expect(snapshots.sortedForObservability(by: .processes).map(\.id) == ["a", "c", "b"])
        #expect(snapshots.sortedForObservability(by: .containerID).map(\.id) == ["a", "b", "c"])
    }

    @Test("prefixes and limits global live log chunks")
    func prefixesAndLimitsGlobalLiveLogChunks() {
        let prefixed = GlobalLogStreamFormatter.prefix(
            chunk: "ready\nserving",
            containerID: "abcdef1234567890abcdef",
            imageName: "example/api:latest"
        )

        #expect(prefixed == "[abcdef1234567890ab] example/api:latest ready\n[abcdef1234567890ab] example/api:latest serving")
        #expect(GlobalLogStreamFormatter.limited("abcdef", maxCharacters: 3) == "def")
        #expect(GlobalLogStreamFormatter.limited("abcdef", maxCharacters: 8) == "abcdef")
        #expect(GlobalLogStreamFormatter.prefixSystem(chunk: "service ready") == "\(AppBranding.logPrefix) service ready")
    }

    @Test("normalizes observability input ranges")
    func normalizesObservabilityInputRanges() {
        #expect(ObservabilityInputNormalizer.logLines("5") == 20)
        #expect(ObservabilityInputNormalizer.logLines("2500") == 1000)
        #expect(ObservabilityInputNormalizer.logLines("240") == 240)
        #expect(ObservabilityInputNormalizer.logLines("bad") == 120)

        #expect(ObservabilityInputNormalizer.systemLogLast("") == "5m")
        #expect(ObservabilityInputNormalizer.systemLogLast("15M") == "15m")
        #expect(ObservabilityInputNormalizer.systemLogLast("2h") == "2h")
        #expect(ObservabilityInputNormalizer.systemLogLast("60") == "60")
        #expect(ObservabilityInputNormalizer.systemLogLast("0d") == "5m")
    }

    @Test("filters containers by compose observability scope")
    func filtersContainersByComposeScope() {
        let project = ComposeProject(
            path: URL(fileURLWithPath: "/tmp/demo-compose.yml"),
            name: "demo",
            services: [
                .init(name: "web", image: "nginx:latest"),
                .init(name: "api", image: "example/api:latest"),
            ],
            volumes: [],
            networks: [],
            lastModified: Date(timeIntervalSince1970: 0)
        )
        let containers = [
            makeContainer(
                id: "container-web",
                image: "nginx:latest",
                labels: [
                    "com.docker.compose.project": "demo",
                    "com.docker.compose.service": "web",
                ]
            ),
            makeContainer(id: "demo-api-1", image: "example/api:latest"),
            makeContainer(id: "standalone", image: "redis:latest"),
        ]

        #expect(ObservabilityComposeScope.all.containers(from: containers, projects: [project]).map(\.id) == ["container-web", "demo-api-1", "standalone"])
        #expect(ObservabilityComposeScope.project(project.id).containers(from: containers, projects: [project]).map(\.id) == ["container-web", "demo-api-1"])
        #expect(ObservabilityComposeScope.service(projectID: project.id, serviceName: "web").containers(from: containers, projects: [project]).map(\.id) == ["container-web"])
    }

    @Test("filters global log text by selected containers")
    func filtersGlobalLogTextBySelectedContainers() {
        let sectionLogs = """
        [demo-web-1] nginx:latest
        web ready

        [demo-api-1] example/api:latest
        api ready
        """
        let liveLogs = """
        [demo-web-1] nginx:latest web ready
        [demo-api-1] example/api:latest api ready
        \(AppBranding.logPrefix) stream notice
        """
        let legacyLiveLogs = """
        [demo-web-1] nginx:latest web ready
        [demo-api-1] example/api:latest api ready
        \(AppBranding.legacyLogPrefix) stream notice
        """

        #expect(GlobalLogStreamFormatter.filtered(sectionLogs, containerIDs: ["demo-web-1"]) == "[demo-web-1] nginx:latest\nweb ready")
        #expect(GlobalLogStreamFormatter.filtered(liveLogs, containerIDs: ["demo-web-1"]) == "[demo-web-1] nginx:latest web ready\n\(AppBranding.logPrefix) stream notice")
        #expect(GlobalLogStreamFormatter.filtered(legacyLiveLogs, containerIDs: ["demo-web-1"]) == "[demo-web-1] nginx:latest web ready\n\(AppBranding.legacyLogPrefix) stream notice")
        #expect(GlobalLogStreamFormatter.filtered(liveLogs, containerIDs: []) == "")
    }

    private func makeSnapshot(
        id: String,
        blockReadBytes: Int64 = 0,
        blockWriteBytes: Int64 = 0,
        cpuUsageUsec: Int64 = 0,
        memoryLimitBytes: Int64 = 0,
        memoryUsageBytes: Int64 = 0,
        networkRxBytes: Int64 = 0,
        networkTxBytes: Int64 = 0,
        numProcesses: Int = 0
    ) -> ContainerStatsSnapshot {
        ContainerStatsSnapshot(
            id: id,
            blockReadBytes: blockReadBytes,
            blockWriteBytes: blockWriteBytes,
            cpuUsageUsec: cpuUsageUsec,
            memoryLimitBytes: memoryLimitBytes,
            memoryUsageBytes: memoryUsageBytes,
            networkRxBytes: networkRxBytes,
            networkTxBytes: networkTxBytes,
            numProcesses: numProcesses
        )
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
