import SwiftUI

struct SystemCleanupPanel: View {
    @Environment(\.appLanguage) private var language
    var diskUsage: DiskUsageSummary?
    var beforeDiskUsage: DiskUsageSummary?
    var afterDiskUsage: DiskUsageSummary?
    var statusMessage: String?
    var isError: Bool
    var isRunning: Bool
    @Binding var plan: SystemCleanupPlan
    var onCleanup: () -> Void

    private var hasSelection: Bool {
        !plan.isEmpty
    }

    var body: some View {
        PanelView(
            title: localized("空间清理", "Space Cleanup"),
            subtitle: localized("按分类选择要清理的资源", "Choose resource categories to clean"),
            systemImage: "trash"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                cleanupWorkspace
                statusAndDelta
                footer
            }
        }
    }

    private var cleanupWorkspace: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 14) {
                metrics
                    .frame(width: 260, alignment: .topLeading)
                cleanupOptions
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            VStack(alignment: .leading, spacing: 14) {
                metrics
                cleanupOptions
            }
        }
    }

    @ViewBuilder
    private var metrics: some View {
        if let diskUsage {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    CleanupMetricTile(title: localized("总占用", "Total"), value: diskUsage.totalSizeDisplay)
                    CleanupMetricTile(title: localized("总可回收", "Reclaimable"), value: diskUsage.reclaimableDisplay)
                    CleanupMetricTile(title: localized("本次估算", "Selected"), value: plan.estimatedReclaimableDisplay(in: diskUsage))
                }

                VStack(alignment: .leading, spacing: 10) {
                    CleanupMetricTile(title: localized("总占用", "Total"), value: diskUsage.totalSizeDisplay)
                    CleanupMetricTile(title: localized("总可回收", "Reclaimable"), value: diskUsage.reclaimableDisplay)
                    CleanupMetricTile(title: localized("本次估算", "Selected"), value: plan.estimatedReclaimableDisplay(in: diskUsage))
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        } else {
            Text(localized("暂无磁盘使用数据，刷新后可查看可回收空间。", "Disk usage is unavailable. Refresh to inspect reclaimable space."))
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var cleanupOptions: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(localized("清理分类", "Cleanup Categories"))
                    .font(.callout.weight(.semibold))
                Spacer()
                Button(localized("推荐", "Recommended")) {
                    plan.categories = SystemCleanupCategory.safeDefaults
                }
                .buttonStyle(CDSecondaryButtonStyle())
                .help(localized("选择默认安全清理分类", "Select the default safe cleanup categories"))

                Button(localized("全选", "All")) {
                    plan.categories = Set(SystemCleanupCategory.allCases)
                }
                .buttonStyle(CDSecondaryButtonStyle())
                .help(localized("选择全部可清理分类", "Select every cleanup category"))

                Button(localized("清空", "Clear")) {
                    plan.categories = []
                }
                .buttonStyle(CDSecondaryButtonStyle())
                .disabled(plan.isEmpty)
                .help(localized("清空当前选择", "Clear the current selection"))
            }

            VStack(spacing: 8) {
                ForEach(SystemCleanupCategory.allCases) { category in
                    CleanupCategoryRow(
                        category: category,
                        diskUsage: diskUsage,
                        isSelected: plan.categories.contains(category)
                    ) {
                        toggle(category)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var statusAndDelta: some View {
        if let statusMessage {
            StatusBanner(
                text: statusMessage,
                systemImage: isError ? "exclamationmark.triangle" : "checkmark.circle",
                tint: isError ? CDTheme.ember : CDTheme.lime
            )
        }

        if let beforeDiskUsage, let afterDiskUsage {
            HStack(spacing: 10) {
                CleanupDeltaLabel(title: localized("清理前", "Before"), diskUsage: beforeDiskUsage)
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                CleanupDeltaLabel(title: localized("清理后", "After"), diskUsage: afterDiskUsage)
            }
            .font(.caption)
        }
    }

    private var footer: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                cleanupHint
                Spacer()
                cleanupButton
            }

            VStack(alignment: .leading, spacing: 12) {
                cleanupHint
                cleanupButton
            }
        }
    }

    private var cleanupHint: some View {
        Label(
            plan.includesVolumes
                ? localized("已包含卷清理：只删除未被容器引用的卷，请先确认不需要这些数据。", "Volume cleanup is included. Only volumes not referenced by containers are removed; confirm the data is no longer needed.")
                : localized("默认推荐只清理停止容器和无标签镜像，不删除卷。", "The recommended default cleans stopped containers and dangling images without deleting volumes."),
            systemImage: plan.includesVolumes ? "exclamationmark.triangle" : "checkmark.shield"
        )
        .font(.callout)
        .foregroundStyle(plan.includesVolumes ? CDTheme.ember : .secondary)
    }

    private var cleanupButton: some View {
        Button {
            onCleanup()
        } label: {
            if isRunning {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(localized("清理中", "Cleaning"))
                }
            } else {
                Label(localized("清理所选", "Clean Selected"), systemImage: "sparkles")
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(isRunning || !hasSelection)
        .help(localized("清理当前勾选的资源分类", "Clean the selected resource categories"))
    }

    private func toggle(_ category: SystemCleanupCategory) {
        if plan.categories.contains(category) {
            plan.categories.remove(category)
        } else {
            plan.categories.insert(category)
        }
    }

    private func localized(_ zh: String, _ en: String) -> String {
        language.resolved == .zhHans ? zh : en
    }
}

private struct CleanupCategoryRow: View {
    @Environment(\.appLanguage) private var language
    var category: SystemCleanupCategory
    var diskUsage: DiskUsageSummary?
    var isSelected: Bool
    var onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? CDTheme.dockerBlue : .secondary)
                    .frame(width: 20, height: 20)

                Image(systemName: category.systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(category.isVolumeDestructive ? CDTheme.ember : CDTheme.dockerBlue)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(category.title(language: language))
                            .font(.callout.weight(.semibold))
                        if category.isVolumeDestructive {
                            Text(language.resolved == .zhHans ? "可删除数据" : "Deletes data")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(CDTheme.ember)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(CDTheme.ember.opacity(0.10), in: Capsule())
                        }
                    }
                    Text(category.subtitle(language: language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(category.commandPreview)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(category.reclaimableDisplay(in: diskUsage))
                        .font(.callout.weight(.semibold).monospacedDigit())
                    Text(category.objectSummary(in: diskUsage, language: language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? CDTheme.dockerBlue.opacity(0.45) : CDTheme.separator)
            }
        }
        .buttonStyle(.plain)
    }

    private var rowBackground: Color {
        isSelected ? CDTheme.dockerBlue.opacity(0.08) : CDTheme.elevatedSurface
    }
}

private struct CleanupMetricTile: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CDTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }
}

private struct CleanupDeltaLabel: View {
    var title: String
    var diskUsage: DiskUsageSummary

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(diskUsage.reclaimableDisplay)
                .font(.caption.monospacedDigit())
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(CDTheme.elevatedSurface, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(CDTheme.separator)
        }
    }
}
