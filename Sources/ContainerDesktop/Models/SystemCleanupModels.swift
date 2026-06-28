import Foundation

enum SystemCleanupCategory: String, CaseIterable, Identifiable, Hashable, Sendable {
    case stoppedContainers
    case danglingImages
    case unusedVolumes

    var id: String { rawValue }

    static let safeDefaults: Set<SystemCleanupCategory> = [.stoppedContainers, .danglingImages]

    var commandPreview: String {
        switch self {
        case .stoppedContainers:
            "container prune"
        case .danglingImages:
            "container image prune"
        case .unusedVolumes:
            "container volume prune"
        }
    }

    var systemImage: String {
        switch self {
        case .stoppedContainers:
            "shippingbox"
        case .danglingImages:
            "photo.stack"
        case .unusedVolumes:
            "externaldrive"
        }
    }

    var isVolumeDestructive: Bool {
        self == .unusedVolumes
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .stoppedContainers:
            language.resolved == .zhHans ? "已停止容器" : "Stopped Containers"
        case .danglingImages:
            language.resolved == .zhHans ? "无标签镜像" : "Dangling Images"
        case .unusedVolumes:
            language.resolved == .zhHans ? "未使用卷" : "Unused Volumes"
        }
    }

    func subtitle(language: AppLanguage) -> String {
        switch self {
        case .stoppedContainers:
            language.resolved == .zhHans
                ? "删除已经停止、不会再运行的容器记录。"
                : "Remove stopped container records that are no longer running."
        case .danglingImages:
            language.resolved == .zhHans
                ? "删除 dangling/无标签镜像，不删除被容器引用的镜像。"
                : "Remove dangling images while keeping images referenced by containers."
        case .unusedVolumes:
            language.resolved == .zhHans
                ? "删除未被任何容器引用的卷；如果仍需数据，请不要勾选。"
                : "Remove volumes not referenced by containers. Leave unchecked if the data is still needed."
        }
    }

    func resource(in diskUsage: DiskUsageSummary?) -> DiskUsageSummary.Resource? {
        guard let diskUsage else { return nil }
        switch self {
        case .stoppedContainers:
            return diskUsage.containers
        case .danglingImages:
            return diskUsage.images
        case .unusedVolumes:
            return diskUsage.volumes
        }
    }

    func reclaimableBytes(in diskUsage: DiskUsageSummary?) -> Int64 {
        resource(in: diskUsage)?.reclaimable ?? 0
    }

    func reclaimableDisplay(in diskUsage: DiskUsageSummary?) -> String {
        ByteCountFormatter.string(fromByteCount: reclaimableBytes(in: diskUsage), countStyle: .file)
    }

    func objectSummary(in diskUsage: DiskUsageSummary?, language: AppLanguage) -> String {
        guard let resource = resource(in: diskUsage) else {
            return language.resolved == .zhHans ? "等待磁盘统计" : "Waiting for disk stats"
        }
        if language.resolved == .zhHans {
            return "总数 \(resource.total)，活跃 \(resource.active)"
        }
        return "\(resource.total) total, \(resource.active) active"
    }
}

struct SystemCleanupPlan: Equatable, Sendable {
    var categories: Set<SystemCleanupCategory>

    static let safeDefault = SystemCleanupPlan(categories: SystemCleanupCategory.safeDefaults)

    var sortedCategories: [SystemCleanupCategory] {
        SystemCleanupCategory.allCases.filter { categories.contains($0) }
    }

    var isEmpty: Bool {
        categories.isEmpty
    }

    var commandPreview: String {
        sortedCategories.map(\.commandPreview).joined(separator: "\n")
    }

    var includesVolumes: Bool {
        categories.contains(.unusedVolumes)
    }

    func estimatedReclaimableBytes(in diskUsage: DiskUsageSummary?) -> Int64 {
        sortedCategories.reduce(Int64(0)) { total, category in
            total + category.reclaimableBytes(in: diskUsage)
        }
    }

    func estimatedReclaimableDisplay(in diskUsage: DiskUsageSummary?) -> String {
        ByteCountFormatter.string(fromByteCount: estimatedReclaimableBytes(in: diskUsage), countStyle: .file)
    }

    func categoryTitles(language: AppLanguage) -> [String] {
        sortedCategories.map { $0.title(language: language) }
    }
}
