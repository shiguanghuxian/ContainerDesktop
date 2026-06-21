import SwiftUI

struct DashboardView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var runtimeStore: RuntimeStore
    @Bindable var composeStore: ComposeProjectStore
    @Bindable var systemConfigStore: SystemConfigStore
    var onOpenResourceSnapshot: () -> Void

    private let metricColumns = [
        GridItem(.adaptive(minimum: 176), spacing: 12),
    ]

    private var runningContainers: Int {
        runtimeStore.containers.filter { $0.state == "running" }.count
    }

    private var runningMachines: Int {
        runtimeStore.machines.filter(\.isRunning).count
    }

    private var defaultMachineText: String {
        runtimeStore.machines.first(where: \.isDefault)?.id ?? "—"
    }

    private var systemVersionText: String {
        if let version = runtimeStore.systemVersions.first(where: { $0.appName.localizedCaseInsensitiveContains("container") }) {
            return version.version
        }
        if let version = runtimeStore.systemVersions.first {
            return version.version
        }
        return runtimeStore.environment.systemVersion ?? "—"
    }

    private var lastUpdatedText: String {
        runtimeStore.lastUpdated?.formatted(date: .omitted, time: .shortened) ?? "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PageHeader(
                title: AppBranding.displayName,
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
                        onOpenResourceSnapshot()
                    } label: {
                        Label(language.resolved == .zhHans ? "资源快照" : "Stats Snapshot", systemImage: "sidebar.right")
                    }
                    .buttonStyle(.bordered)
                    .help(language.resolved == .zhHans ? "在观测页面打开资源快照" : "Open stats snapshot in Observability")

                    Button {
                        refreshDashboard()
                    } label: {
                        Label(language.t(.refresh), systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .help(language.resolved == .zhHans ? "刷新 Dashboard 数据" : "Refresh dashboard data")
                }
            }

            if !DependencyInstallTarget.missing(in: runtimeStore.environment).isEmpty {
                DependencyInstallGuideView(environment: runtimeStore.environment) {
                    Task {
                        await runtimeStore.refreshAll()
                        await composeStore.refreshVersion()
                    }
                }
            }

            LazyVGrid(columns: metricColumns, spacing: 12) {
                DashboardMetricCard(
                    title: language.t(.containers),
                    value: "\(runtimeStore.containers.count)",
                    detail: language.resolved == .zhHans ? "\(runningContainers) 个运行中，\(runtimeStore.containers.count - runningContainers) 个已停止。" : "\(runningContainers) running, \(runtimeStore.containers.count - runningContainers) stopped.",
                    systemImage: "shippingbox",
                    tint: CDTheme.cyan
                )
                DashboardMetricCard(
                    title: language.t(.machines),
                    value: "\(runtimeStore.machines.count)",
                    detail: language.resolved == .zhHans ? "\(runningMachines) 个运行中，\(runtimeStore.machines.count - runningMachines) 个已停止。" : "\(runningMachines) running, \(runtimeStore.machines.count - runningMachines) stopped.",
                    systemImage: "desktopcomputer",
                    tint: CDTheme.dockerBlue
                )
                DashboardMetricCard(
                    title: language.t(.images),
                    value: "\(runtimeStore.images.count)",
                    detail: language.resolved == .zhHans ? "本地可用 OCI 镜像。" : "Local OCI images ready to run.",
                    systemImage: "photo.stack",
                    tint: CDTheme.violet
                )
                DashboardMetricCard(
                    title: language.t(.volumes),
                    value: "\(runtimeStore.volumes.count)",
                    detail: language.resolved == .zhHans ? "命名卷和匿名卷。" : "Named and anonymous volumes.",
                    systemImage: "externaldrive",
                    tint: CDTheme.lime
                )
                DashboardMetricCard(
                    title: language.t(.networks),
                    value: "\(runtimeStore.networks.count)",
                    detail: language.resolved == .zhHans ? "系统网络和用户自定义网络。" : "System and user-defined networks.",
                    systemImage: "network",
                    tint: CDTheme.ember
                )
            }

            EnvironmentResourceMonitorPanel(
                snapshot: runtimeStore.resourceMonitorSnapshot,
                hostProcesses: runtimeStore.hostProcessSnapshots,
                errorMessage: runtimeStore.resourceMonitorErrorMessage,
                compact: true
            )

            if let diskUsage = runtimeStore.diskUsage {
                CompactDiskUsagePanel(diskUsage: diskUsage)
            }

            let onboardingIssues = runtimeStore.onboardingIssues(language: language)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    OperationsOverviewPanel(
                        statusTitle: runtimeStore.statusTitle(language: language),
                        statusSystemImage: runtimeStore.environment.systemRunning ? "checkmark.circle" : "exclamationmark.triangle",
                        statusTint: runtimeStore.environment.systemRunning ? CDTheme.lime : CDTheme.ember,
                        lastUpdated: lastUpdatedText,
                        systemVersion: systemVersionText,
                        defaultMachine: defaultMachineText,
                        registriesCount: runtimeStore.registries.count,
                        composeProjectsCount: composeStore.projects.count
                    )
                    .frame(maxWidth: .infinity)

                    if onboardingIssues.isEmpty {
                        CompactEnvironmentPanel(environment: runtimeStore.environment)
                            .frame(maxWidth: .infinity)
                    } else {
                        CompactOnboardingPanel(issues: onboardingIssues)
                            .frame(maxWidth: .infinity)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    OperationsOverviewPanel(
                        statusTitle: runtimeStore.statusTitle(language: language),
                        statusSystemImage: runtimeStore.environment.systemRunning ? "checkmark.circle" : "exclamationmark.triangle",
                        statusTint: runtimeStore.environment.systemRunning ? CDTheme.lime : CDTheme.ember,
                        lastUpdated: lastUpdatedText,
                        systemVersion: systemVersionText,
                        defaultMachine: defaultMachineText,
                        registriesCount: runtimeStore.registries.count,
                        composeProjectsCount: composeStore.projects.count
                    )

                    if onboardingIssues.isEmpty {
                        CompactEnvironmentPanel(environment: runtimeStore.environment)
                    } else {
                        CompactOnboardingPanel(issues: onboardingIssues)
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
        .task(id: runtimeStore.isReady) {
            guard runtimeStore.isReady else { return }
            runtimeStore.startResourceMonitoring(interval: 2)
        }
        .onDisappear {
            runtimeStore.stopResourceMonitoring()
        }
    }

    private func refreshDashboard() {
        Task {
            await runtimeStore.refreshAll()
            await runtimeStore.refreshResourceMonitorOnce()
        }
    }
}

private struct DashboardMetricCard: View {
    var title: String
    var value: String
    var detail: String
    var systemImage: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                IconTile(systemImage: systemImage, tint: tint, size: 28)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(value)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Capsule()
                    .fill(tint)
                    .frame(width: 28, height: 3)
                    .opacity(0.78)
            }

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
        .glassPanel(accent: tint)
    }
}

private struct CompactDashboardPanel<Content: View>: View {
    var title: String
    var subtitle: String?
    var systemImage: String
    var accent: Color = CDTheme.dockerBlue
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                IconTile(systemImage: systemImage, tint: accent, size: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }

            content
        }
        .padding(12)
        .glassPanel(accent: accent)
    }
}

private struct OperationsOverviewPanel: View {
    @Environment(\.appLanguage) private var language
    var statusTitle: String
    var statusSystemImage: String
    var statusTint: Color
    var lastUpdated: String
    var systemVersion: String
    var defaultMachine: String
    var registriesCount: Int
    var composeProjectsCount: Int

    private let columns = [
        GridItem(.adaptive(minimum: 138), spacing: 8),
    ]

    var body: some View {
        CompactDashboardPanel(
            title: localized("运行概况", "Operations"),
            subtitle: localized("不额外请求 CLI 的实时摘要", "Live summary from loaded data"),
            systemImage: "gauge.with.dots.needle.67percent",
            accent: CDTheme.dockerBlue
        ) {
            LazyVGrid(columns: columns, spacing: 8) {
                DashboardInfoChip(title: language.t(.status), value: statusTitle, systemImage: statusSystemImage, tint: statusTint)
                DashboardInfoChip(title: localized("最后刷新", "Last refresh"), value: lastUpdated, systemImage: "clock", tint: CDTheme.cyan)
                DashboardInfoChip(title: localized("系统版本", "System version"), value: systemVersion, systemImage: "number", tint: CDTheme.violet)
                DashboardInfoChip(title: language.t(.defaultMachine), value: defaultMachine, systemImage: "star", tint: CDTheme.ember)
                DashboardInfoChip(title: language.t(.registries), value: "\(registriesCount)", systemImage: "key.icloud", tint: CDTheme.lime)
                DashboardInfoChip(title: language.t(.compose), value: "\(composeProjectsCount)", systemImage: "square.stack.3d.up", tint: CDTheme.dockerBlue)
            }
        }
    }

    private func localized(_ zh: String, _ en: String) -> String {
        language.resolved == .zhHans ? zh : en
    }
}

private struct CompactEnvironmentPanel: View {
    @Environment(\.appLanguage) private var language
    var environment: EnvironmentProbe

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 8),
    ]

    var body: some View {
        CompactDashboardPanel(
            title: language.t(.environment),
            subtitle: "container system status",
            systemImage: "shield.lefthalf.filled",
            accent: CDTheme.cyan
        ) {
            LazyVGrid(columns: columns, spacing: 8) {
                DashboardInfoChip(title: "macOS", value: environment.macOSVersion, systemImage: "macwindow", tint: CDTheme.dockerBlue)
                DashboardInfoChip(title: "Architecture", value: environment.architecture, systemImage: "cpu", tint: CDTheme.violet)
                DashboardInfoChip(title: "container", value: environment.containerAvailable ? "available" : "missing", systemImage: "terminal", tint: environment.containerAvailable ? CDTheme.lime : CDTheme.ember)
                DashboardInfoChip(title: "container-compose", value: environment.containerComposeAvailable ? "available" : "missing", systemImage: "square.stack.3d.up", tint: environment.containerComposeAvailable ? CDTheme.lime : CDTheme.ember)
            }
        }
    }
}

private struct CompactOnboardingPanel: View {
    @Environment(\.appLanguage) private var language
    var issues: [String]

    var body: some View {
        CompactDashboardPanel(
            title: language.resolved == .zhHans ? "首次引导" : "First Run",
            subtitle: language.resolved == .zhHans ? "缺失项会阻止完全管理功能" : "Missing prerequisites block full management features.",
            systemImage: "exclamationmark.shield",
            accent: CDTheme.ember
        ) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(issues, id: \.self) { issue in
                    Label(issue, systemImage: "dot.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text(language.resolved == .zhHans ? "安装后可在右上角刷新状态。" : "Refresh status from the top-right after installation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct DashboardInfoChip: View {
    var title: String
    var value: String
    var systemImage: String
    var tint: Color

    var body: some View {
        HStack(spacing: 8) {
            IconTile(systemImage: systemImage, tint: tint, size: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .frame(height: 44)
        .background(CDTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.hairline)
        }
    }
}

private struct CompactDiskUsagePanel: View {
    @Environment(\.appLanguage) private var language
    var diskUsage: DiskUsageSummary

    var body: some View {
        CompactDashboardPanel(
            title: localized("磁盘使用", "Disk Usage"),
            subtitle: "container system df",
            systemImage: "internaldrive",
            accent: CDTheme.dockerBlue
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 20) {
                    DiskSummaryValue(
                        title: localized("本地资源总占用", "Total local resource size"),
                        value: diskUsage.totalSizeDisplay,
                        alignment: .leading
                    )

                    Spacer(minLength: 16)

                    DiskSummaryValue(
                        title: localized("可回收空间", "Reclaimable"),
                        value: diskUsage.reclaimableDisplay,
                        alignment: .trailing
                    )
                }

                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Text(localized("对象", "Objects"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(localized("总数", "Total"))
                            .frame(width: 54, alignment: .trailing)
                        Text(localized("活跃", "Active"))
                            .frame(width: 54, alignment: .trailing)
                        Text(language.t(.size))
                            .frame(width: 92, alignment: .trailing)
                        Text(localized("可回收", "Reclaimable"))
                            .frame(width: 96, alignment: .trailing)
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .frame(height: 26)

                    Divider()

                    ForEach(diskUsage.resources, id: \.name) { item in
                        CompactDiskUsageRow(name: localizedName(item.name), resource: item.value)
                    }
                }
                .background(CDTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(CDTheme.separator)
                }
            }
        }
    }

    private func localized(_ zh: String, _ en: String) -> String {
        language.resolved == .zhHans ? zh : en
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

private struct DiskSummaryValue: View {
    var title: String
    var value: String
    var alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.74)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct CompactDiskUsageRow: View {
    var name: String
    var resource: DiskUsageSummary.Resource

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    CompactProgressBar(value: resource.reclaimableRatio)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(resource.total)")
                    .frame(width: 54, alignment: .trailing)
                Text("\(resource.active)")
                    .frame(width: 54, alignment: .trailing)
                Text(resource.sizeDisplay)
                    .monospacedDigit()
                    .frame(width: 92, alignment: .trailing)
                Text(resource.reclaimableDisplay)
                    .monospacedDigit()
                    .foregroundStyle(resource.reclaimable > 0 ? CDTheme.ember : .secondary)
                    .frame(width: 96, alignment: .trailing)
            }
            .font(.caption)
            .padding(.horizontal, 10)
            .frame(height: 40)

            Divider()
                .padding(.leading, 10)
        }
    }
}

private struct CompactProgressBar: View {
    var value: Double

    var body: some View {
        GeometryReader { proxy in
            let width = max(2, proxy.size.width * min(max(value, 0), 1))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(CDTheme.hairline.opacity(0.46))
                Capsule()
                    .fill(CDTheme.dockerBlue)
                    .frame(width: width)
            }
        }
        .frame(height: 5)
    }
}
