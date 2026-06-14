import Foundation
import Observation

@MainActor
@Observable
final class ComposeServiceObservationStore {
    typealias LogsLoader = @Sendable (_ containerID: String, _ lines: Int) async throws -> String
    typealias StatsLoader = @Sendable (_ containerIDs: [String]) async throws -> [ContainerStatsSnapshot]

    private let logsLoader: LogsLoader
    private let statsLoader: StatsLoader

    var selectedServiceName: String?
    var selectedContainerIDs: [String] = []
    var logsText = ""
    var statsSnapshots: [ContainerStatsSnapshot] = []
    var isLoading = false
    var errorMessage: String?
    var lastUpdated: Date?

    init(client: ContainerCLIClient = ContainerCLIClient()) {
        self.logsLoader = { containerID, lines in
            try await client.containerLogs(containerID, lines: lines)
        }
        self.statsLoader = { containerIDs in
            try await client.containerStats(containerIDs)
        }
    }

    init(
        logsLoader: @escaping LogsLoader,
        statsLoader: @escaping StatsLoader
    ) {
        self.logsLoader = logsLoader
        self.statsLoader = statsLoader
    }

    var statsSummary: ObservabilityStatsSummary? {
        guard !statsSnapshots.isEmpty else { return nil }
        return ObservabilityStatsSummary(snapshots: statsSnapshots)
    }

    func load(summary: ComposeServiceRuntimeSummary, lines: Int = 160) async {
        await load(
            scopeName: summary.service.name,
            containers: summary.containers,
            emptyMessage: "该服务还没有匹配到容器。",
            lines: lines
        )
    }

    func loadProject(projectName: String, summaries: [ComposeServiceRuntimeSummary], lines: Int = 160) async {
        var seenIDs = Set<String>()
        let containers = summaries
            .flatMap(\.containers)
            .filter { container in
                if seenIDs.contains(container.id) { return false }
                seenIDs.insert(container.id)
                return true
            }

        await load(
            scopeName: "\(projectName) / all services",
            containers: containers,
            emptyMessage: "该项目还没有匹配到容器。",
            lines: lines
        )
    }

    private func load(scopeName: String, containers: [ContainerSummary], emptyMessage: String, lines: Int) async {
        guard !isLoading else { return }

        selectedServiceName = scopeName
        selectedContainerIDs = containers.map(\.id)
        logsText = "加载日志..."
        statsSnapshots = []
        errorMessage = nil
        isLoading = true
        defer {
            isLoading = false
            lastUpdated = Date()
        }

        guard !containers.isEmpty else {
            logsText = emptyMessage
            return
        }

        let containerIDs = containers.map(\.id)
        do {
            statsSnapshots = try await statsLoader(containerIDs)
        } catch {
            statsSnapshots = []
            errorMessage = "Stats 加载失败：\(error.localizedDescription)"
        }

        var logSections: [String] = []
        for container in containers.prefix(16) {
            do {
                let output = try await logsLoader(container.id, lines)
                let logText = output.nilIfBlank ?? "暂无日志。"
                logSections.append("[\(container.id)] \(container.imageName)\n\(logText)")
            } catch {
                let message = "日志加载失败：\(error.localizedDescription)"
                errorMessage = [errorMessage, message].compactMap { $0?.nilIfBlank }.joined(separator: "\n")
                logSections.append("[\(container.id)] \(container.imageName)\n\(message)")
            }
        }

        if containers.count > 16 {
            logSections.append("已省略 \(containers.count - 16) 个容器的日志，避免一次加载过多内容。")
        }

        logsText = logSections.joined(separator: "\n\n")
    }

    func clear() {
        selectedServiceName = nil
        selectedContainerIDs = []
        logsText = ""
        statsSnapshots = []
        errorMessage = nil
        lastUpdated = nil
    }
}
