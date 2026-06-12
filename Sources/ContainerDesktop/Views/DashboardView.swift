import SwiftUI

struct DashboardView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var runtimeStore: RuntimeStore
    @Bindable var composeStore: ComposeProjectStore
    @Bindable var systemConfigStore: SystemConfigStore

    private let columns = [
        GridItem(.adaptive(minimum: 240), spacing: 14),
    ]

    private var runningContainers: Int {
        runtimeStore.containers.filter { $0.state == "running" }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeader(
                title: "ContainerDesktop",
                subtitle: language.t(.dashboardSubtitle),
                systemImage: "shippingbox.fill"
            ) {
                HStack(spacing: 8) {
                    StatusPill(
                        title: runtimeStore.statusTitle(language: language),
                        systemImage: runtimeStore.environment.systemRunning ? "checkmark.circle" : "exclamationmark.triangle",
                        tint: runtimeStore.environment.systemRunning ? .green : .orange
                    )
                    Button {
                        Task { await runtimeStore.refreshAll() }
                    } label: {
                        Label(language.t(.refresh), systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            LazyVGrid(columns: columns, spacing: 14) {
                MetricCard(
                    title: language.t(.containers),
                    value: "\(runtimeStore.containers.count)",
                    detail: language.resolved == .zhHans ? "\(runningContainers) 个运行中，\(runtimeStore.containers.count - runningContainers) 个已停止。" : "\(runningContainers) running, \(runtimeStore.containers.count - runningContainers) stopped.",
                    systemImage: "shippingbox",
                    tint: CDTheme.cyan
                )
                MetricCard(
                    title: language.t(.images),
                    value: "\(runtimeStore.images.count)",
                    detail: language.resolved == .zhHans ? "本地可用 OCI 镜像。" : "Local OCI images ready to run.",
                    systemImage: "photo.stack",
                    tint: CDTheme.violet
                )
                MetricCard(
                    title: language.t(.volumes),
                    value: "\(runtimeStore.volumes.count)",
                    detail: language.resolved == .zhHans ? "命名卷和匿名卷。" : "Named and anonymous volumes.",
                    systemImage: "externaldrive",
                    tint: CDTheme.lime
                )
                MetricCard(
                    title: language.t(.networks),
                    value: "\(runtimeStore.networks.count)",
                    detail: language.resolved == .zhHans ? "系统网络和用户自定义网络。" : "System and user-defined networks.",
                    systemImage: "network",
                    tint: CDTheme.ember
                )
            }

            if let diskUsage = runtimeStore.diskUsage {
                DiskUsagePanel(diskUsage: diskUsage)
            }

            let onboardingIssues = runtimeStore.onboardingIssues(language: language)

            if onboardingIssues.isEmpty {
                PanelView(title: language.t(.environment), subtitle: "container system status", systemImage: "shield.lefthalf.filled") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                        EnvironmentTile(title: "macOS", value: runtimeStore.environment.macOSVersion, systemImage: "macwindow")
                        EnvironmentTile(title: "Architecture", value: runtimeStore.environment.architecture, systemImage: "cpu")
                        EnvironmentTile(title: "container", value: runtimeStore.environment.containerAvailable ? "available" : "missing", systemImage: "terminal")
                        EnvironmentTile(title: "container-compose", value: runtimeStore.environment.containerComposeAvailable ? "available" : "missing", systemImage: "square.stack.3d.up")
                    }
                }
            } else {
                PanelView(
                    title: language.resolved == .zhHans ? "首次引导" : "First Run",
                    subtitle: language.resolved == .zhHans ? "缺失项会阻止完全管理功能" : "Missing prerequisites block full management features.",
                    systemImage: "exclamationmark.shield"
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(onboardingIssues, id: \.self) { issue in
                            Label(issue, systemImage: "dot.circle")
                                .foregroundStyle(.secondary)
                        }
                        Text(language.resolved == .zhHans ? "安装后可在右上角刷新状态。" : "Refresh status from the top-right after installation.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !composeStore.projects.isEmpty {
                PanelView(title: language.t(.recentCompose), subtitle: "Projects", systemImage: "square.stack.3d.up") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(composeStore.projects.prefix(4)) { project in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(project.name)
                                        .font(.headline)
                                    Text(project.path.path)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text("\(project.services.count) services")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6)
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

private struct DiskUsagePanel: View {
    @Environment(\.appLanguage) private var language
    var diskUsage: DiskUsageSummary

    var body: some View {
        PanelView(title: language.resolved == .zhHans ? "磁盘使用" : "Disk Usage", subtitle: "container system df", systemImage: "internaldrive") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(diskUsage.totalSizeDisplay)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(language.resolved == .zhHans ? "本地资源总占用" : "Total local resource size")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(diskUsage.reclaimableDisplay)
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                        Text(language.resolved == .zhHans ? "可回收空间" : "Reclaimable")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(spacing: 0) {
                    HStack {
                        Text(language.resolved == .zhHans ? "对象" : "Objects")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(language.resolved == .zhHans ? "总数" : "Total")
                            .frame(width: 72, alignment: .trailing)
                        Text(language.resolved == .zhHans ? "活跃" : "Active")
                            .frame(width: 72, alignment: .trailing)
                        Text(language.t(.size))
                            .frame(width: 110, alignment: .trailing)
                        Text(language.resolved == .zhHans ? "可回收" : "Reclaimable")
                            .frame(width: 120, alignment: .trailing)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .frame(height: 34)

                    Divider()

                    ForEach(diskUsage.resources, id: \.name) { item in
                        DiskUsageRow(name: localizedName(item.name), resource: item.value)
                    }
                }
                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(CDTheme.separator)
                }
            }
        }
    }

    private func localizedName(_ name: String) -> String {
        guard language.resolved == .zhHans else { return name }
        switch name {
        case "Containers": return language.t(.containers)
        case "Images": return language.t(.images)
        case "Volumes": return language.t(.volumes)
        default: return name
        }
    }
}

private struct DiskUsageRow: View {
    var name: String
    var resource: DiskUsageSummary.Resource

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(name)
                        .font(.callout.weight(.semibold))
                    ProgressView(value: resource.reclaimableRatio)
                        .progressViewStyle(.linear)
                        .tint(CDTheme.dockerBlue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(resource.total)")
                    .frame(width: 72, alignment: .trailing)
                Text("\(resource.active)")
                    .frame(width: 72, alignment: .trailing)
                Text(resource.sizeDisplay)
                    .monospacedDigit()
                    .frame(width: 110, alignment: .trailing)
                Text(resource.reclaimableDisplay)
                    .monospacedDigit()
                    .foregroundStyle(resource.reclaimable > 0 ? CDTheme.ember : .secondary)
                    .frame(width: 120, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .frame(height: 58)

            Divider()
                .padding(.leading, 12)
        }
    }
}

private struct EnvironmentTile: View {
    var title: String
    var value: String
    var systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            IconTile(systemImage: systemImage, tint: CDTheme.dockerBlue, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }
}
