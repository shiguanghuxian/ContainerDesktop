import Foundation

enum DashboardRecommendationSeverity: String, Hashable, Sendable {
    case info
    case warning
    case cleanup
}

struct DashboardRecommendation: Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var detail: String
    var systemImage: String
    var severity: DashboardRecommendationSeverity
    var commandPreview: String?
    var route: AppResourceRoute?
}

enum DashboardRecommendationCatalog {
    static func make(
        containers: [ContainerSummary],
        images: [ImageSummary],
        volumes: [VolumeSummary],
        stats: [ContainerStatsSnapshot],
        environment: EnvironmentProbe,
        language: AppLanguage
    ) -> [DashboardRecommendation] {
        let isChinese = language.resolved == .zhHans
        var recommendations: [DashboardRecommendation] = []

        let stopped = containers.filter { $0.state != "running" }
        if !stopped.isEmpty {
            recommendations.append(DashboardRecommendation(
                id: "stopped-containers",
                title: isChinese ? "有 \(stopped.count) 个已停止容器" : "\(stopped.count) stopped containers",
                detail: isChinese ? "检查是否需要删除或重新启动，释放列表噪音和存储空间。" : "Review whether they should be restarted or deleted.",
                systemImage: "shippingbox",
                severity: .cleanup,
                commandPreview: "container delete \(stopped.prefix(3).map(\.id).joined(separator: " "))",
                route: .container(id: stopped.first?.id ?? "", tab: nil)
            ))
        }

        let danglingImages = images.filter {
            $0.reference.localizedCaseInsensitiveContains("<none>")
                || $0.tag.localizedCaseInsensitiveContains("<none>")
        }
        if !danglingImages.isEmpty {
            recommendations.append(DashboardRecommendation(
                id: "dangling-images",
                title: isChinese ? "可清理无标签镜像" : "Dangling images can be pruned",
                detail: isChinese ? "清理前会保留现有确认流程，并展示底层命令。" : "The existing confirmation flow and command preview are preserved.",
                systemImage: "sparkles",
                severity: .cleanup,
                commandPreview: "container image prune",
                route: .imageTasks
            ))
        }

        let anonymousVolumes = volumes.filter(\.isAnonymous)
        if !anonymousVolumes.isEmpty {
            recommendations.append(DashboardRecommendation(
                id: "anonymous-volumes",
                title: isChinese ? "发现 \(anonymousVolumes.count) 个匿名卷" : "\(anonymousVolumes.count) anonymous volumes",
                detail: isChinese ? "先确认关联容器，再决定是否克隆、导出或删除。" : "Check related containers before cloning, exporting, or deleting.",
                systemImage: "externaldrive",
                severity: .warning,
                commandPreview: "container volume list",
                route: .volume(name: anonymousVolumes.first?.name ?? "", tab: nil)
            ))
        }

        if let highMemory = stats.max(by: { $0.memoryUsageBytes < $1.memoryUsageBytes }),
           highMemory.memoryUsageBytes > 512 * 1024 * 1024 {
            recommendations.append(DashboardRecommendation(
                id: "high-memory-\(highMemory.id)",
                title: isChinese ? "高内存容器：\(highMemory.id)" : "High-memory container: \(highMemory.id)",
                detail: isChinese ? "当前约 \(highMemory.memoryUsageDisplay)，可打开 Stats 查看趋势。" : "Currently around \(highMemory.memoryUsageDisplay); open Stats for trend details.",
                systemImage: "memorychip",
                severity: .warning,
                commandPreview: "container stats --no-stream \(highMemory.id)",
                route: .container(id: highMemory.id, tab: .stats)
            ))
        }

        if environment.containerAvailable, environment.systemRunning, containers.allSatisfy({ $0.state != "running" }) {
            recommendations.append(DashboardRecommendation(
                id: "resource-saver",
                title: isChinese ? "可手动停止空闲 system" : "Idle system can be stopped manually",
                detail: isChinese ? "当前没有运行中容器。这里只提示，不会自动停止。" : "No containers are running. This is only a suggestion, never automatic.",
                systemImage: "moon",
                severity: .info,
                commandPreview: "container system stop",
                route: nil
            ))
        }

        return Array(recommendations.prefix(5))
    }
}
