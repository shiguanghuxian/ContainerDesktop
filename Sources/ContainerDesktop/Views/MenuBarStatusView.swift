import AppKit
import SwiftUI

struct MenuBarStatusView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var runtimeStore: RuntimeStore
    @Bindable var composeStore: ComposeProjectStore
    @Bindable var operationStore: AppOperationStore

    @AppStorage("containerdesktop.selected.section") private var selectedSectionRaw = AppSection.dashboard.rawValue

    private let metricColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    private var runningContainers: Int {
        runtimeStore.containers.filter { $0.state == "running" }.count
    }

    private var runningMachines: Int {
        runtimeStore.machines.filter(\.isRunning).count
    }

    private var statusTint: Color {
        if !runtimeStore.environment.containerAvailable || !runtimeStore.environment.systemRunning {
            return CDTheme.ember
        }
        if operationStore.activeCount > 0 {
            return CDTheme.dockerBlue
        }
        return CDTheme.lime
    }

    private var statusSymbol: String {
        if !runtimeStore.environment.containerAvailable || !runtimeStore.environment.systemRunning {
            return "exclamationmark.triangle.fill"
        }
        if operationStore.activeCount > 0 {
            return "hourglass"
        }
        return "checkmark.circle.fill"
    }

    private var statusSubtitle: String {
        if operationStore.activeCount > 0 {
            return localized("\(operationStore.activeCount) 个任务运行中", "\(operationStore.activeCount) tasks running")
        }
        return localized(
            "\(runningContainers) 个容器运行中，\(runningMachines) 个 Machine 运行中",
            "\(runningContainers) containers, \(runningMachines) machines running"
        )
    }

    private var defaultMachineText: String {
        runtimeStore.machines.first(where: \.isDefault)?.id ?? "—"
    }

    private var lastUpdatedText: String {
        runtimeStore.lastUpdated?.formatted(date: .omitted, time: .shortened) ?? "—"
    }

    private var diskReclaimableRatio: Double {
        guard let diskUsage = runtimeStore.diskUsage, diskUsage.totalSizeInBytes > 0 else { return 0 }
        return min(max(Double(diskUsage.reclaimableSizeInBytes) / Double(diskUsage.totalSizeInBytes), 0), 1)
    }

    private var recentOperations: [AppOperationRecord] {
        operationStore.recent(domains: Set(AppOperationDomain.allCases), limit: 3)
    }

    private var stoppedContainers: Int {
        max(runtimeStore.containers.count - runningContainers, 0)
    }

    private var stoppedMachines: Int {
        max(runtimeStore.machines.count - runningMachines, 0)
    }

    private var systemVersionText: String {
        runtimeStore.systemVersions.first { $0.appName.localizedCaseInsensitiveContains("container") }?.version
            ?? runtimeStore.systemVersions.first?.version
            ?? "—"
    }

    private var totalImageSizeText: String {
        let total = runtimeStore.images.reduce(Int64(0)) { partial, image in
            partial + image.variants.reduce(Int64(0)) { $0 + $1.size }
        }
        guard total > 0 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    healthCard
                    resourceSnapshotCard
                    resourceGrid

                    if operationStore.activeCount > 0 {
                        activeTaskCard
                    }

                    actionsCard
                }
                .padding(12)
            }
            .frame(maxHeight: 360)
            .scrollIndicators(.hidden)

            footer
        }
        .frame(width: 380)
        .background(CDTheme.appBackground)
        .task {
            operationStore.load()
            await runtimeStore.bootstrap()
            await composeStore.load()
            await runtimeStore.refreshResourceMonitorOnce()
        }
    }

    private var runtimeDetailsCard: some View {
        MenuBarPanel(accent: CDTheme.cyan) {
            VStack(alignment: .leading, spacing: 10) {
                MenuBarSectionHeader(
                    title: localized("运行时概况", "Runtime details"),
                    subtitle: localized("版本、默认资源和登录状态", "Versions, defaults, and logins"),
                    systemImage: "gauge.with.dots.needle.bottom.50percent"
                )

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    MenuBarInfoTile(title: "container", value: runtimeStore.environment.containerAvailable ? localized("已安装", "available") : localized("缺失", "missing"))
                    MenuBarInfoTile(title: "container-compose", value: runtimeStore.environment.containerComposeAvailable ? localized("已安装", "available") : localized("缺失", "missing"))
                    MenuBarInfoTile(title: localized("系统版本", "System version"), value: systemVersionText)
                    MenuBarInfoTile(title: localized("默认 Machine", "Default machine"), value: defaultMachineText)
                    MenuBarInfoTile(title: localized("仓库登录", "Registry logins"), value: "\(runtimeStore.registries.count)")
                    MenuBarInfoTile(title: localized("镜像总大小", "Image size"), value: totalImageSizeText)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            MenuBarStatusOrb(systemImage: statusSymbol, tint: statusTint)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text("ContainerDesktop")
                        .font(.headline.weight(.semibold))
                    Text(localized("运行矩阵", "runtime matrix"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(statusTint)
                        .padding(.horizontal, 7)
                        .frame(height: 20)
                        .background(statusTint.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                }
                Text(statusSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            StatusPill(
                title: runtimeStore.statusTitle(language: language),
                systemImage: statusSymbol,
                tint: statusTint
            )
        }
        .padding(14)
        .background {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [
                        statusTint.opacity(0.16),
                        CDTheme.panelSurface,
                        CDTheme.cyan.opacity(0.08),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                MenuBarCircuitBackdrop(tint: statusTint)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(statusTint.opacity(0.32))
                .frame(height: 1)
        }
    }

    private var signalDeck: some View {
        MenuBarPanel(accent: statusTint) {
            VStack(alignment: .leading, spacing: 10) {
                MenuBarSectionHeader(
                    title: localized("状态信号", "Status signals"),
                    subtitle: localized("CLI、System、任务和缓存回收状态", "CLI, system, tasks, and reclaimable cache"),
                    systemImage: "dot.radiowaves.left.and.right"
                )

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    MenuBarSignalPill(
                        title: "CLI",
                        value: runtimeStore.environment.containerAvailable ? localized("在线", "online") : localized("缺失", "missing"),
                        systemImage: runtimeStore.environment.containerAvailable ? "checkmark.circle.fill" : "xmark.octagon.fill",
                        tint: runtimeStore.environment.containerAvailable ? CDTheme.lime : CDTheme.ember
                    )
                    MenuBarSignalPill(
                        title: "System",
                        value: runtimeStore.environment.systemRunning ? localized("运行", "running") : localized("停止", "stopped"),
                        systemImage: runtimeStore.environment.systemRunning ? "bolt.fill" : "bolt.slash.fill",
                        tint: runtimeStore.environment.systemRunning ? CDTheme.lime : CDTheme.ember
                    )
                    MenuBarSignalPill(
                        title: localized("任务", "Tasks"),
                        value: operationStore.activeCount > 0 ? "\(operationStore.activeCount)" : localized("空闲", "idle"),
                        systemImage: operationStore.activeCount > 0 ? "clock.arrow.circlepath" : "checkmark.seal.fill",
                        tint: operationStore.activeCount > 0 ? CDTheme.dockerBlue : CDTheme.lime
                    )
                    MenuBarSignalPill(
                        title: localized("可回收", "Reclaim"),
                        value: runtimeStore.diskUsage?.reclaimableDisplay ?? "—",
                        systemImage: "sparkles",
                        tint: diskReclaimableRatio > 0.12 ? CDTheme.ember : CDTheme.cyan
                    )
                }
            }
        }
    }

    private var resourceSnapshotCard: some View {
        MenuBarPanel(accent: CDTheme.dockerBlue) {
            VStack(alignment: .leading, spacing: 10) {
                MenuBarSectionHeader(
                    title: localized("资源快照", "Resource snapshot"),
                    subtitle: localized("CPU、内存、网络和 I/O", "CPU, memory, network, and I/O"),
                    systemImage: "chart.xyaxis.line"
                )

                if let errorMessage = runtimeStore.resourceMonitorErrorMessage?.nilIfBlank {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(CDTheme.ember)
                        .lineLimit(2)
                }

                if let snapshot = runtimeStore.resourceMonitorSnapshot {
                    LazyVGrid(columns: metricColumns, spacing: 8) {
                        MenuBarMetricCard(
                            title: "CPU",
                            value: String(format: "%.1f%%", snapshot.cpuPercent),
                            subtitle: localized("容器聚合", "containers"),
                            tint: CDTheme.dockerBlue
                        )
                        MenuBarMetricCard(
                            title: "Memory",
                            value: ByteCountFormatter.string(fromByteCount: snapshot.memoryUsageBytes, countStyle: .memory),
                            subtitle: snapshot.memoryLimitBytes > 0 ? snapshot.memoryDisplay : localized("使用中", "in use"),
                            tint: CDTheme.cyan
                        )
                        MenuBarMetricCard(
                            title: "Network",
                            value: ContainerResourceSample.bytesPerSecond(snapshot.networkRxBytesPerSecond + snapshot.networkTxBytesPerSecond),
                            subtitle: snapshot.networkRateDisplay,
                            tint: CDTheme.lime
                        )
                        MenuBarMetricCard(
                            title: "Block I/O",
                            value: ContainerResourceSample.bytesPerSecond(snapshot.blockReadBytesPerSecond + snapshot.blockWriteBytesPerSecond),
                            subtitle: snapshot.blockIORateDisplay,
                            tint: CDTheme.ember
                        )
                    }

                    HStack(spacing: 10) {
                        Label("\(snapshot.numProcesses) PIDs", systemImage: "number")
                        Spacer()
                        Label("\(snapshot.hostMemoryDisplay) RSS", systemImage: "cpu")
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                } else {
                    Label(localized("等待资源数据，点击刷新可立即采样。", "Waiting for resource data. Refresh to sample now."), systemImage: "chart.xyaxis.line")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }

    @ViewBuilder
    private var healthCard: some View {
        let issues = runtimeStore.onboardingIssues(language: language)

        if issues.isEmpty {
            MenuBarPanel(accent: CDTheme.lime) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(CDTheme.lime)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localized("运行时就绪", "Runtime ready"))
                            .font(.callout.weight(.semibold))
                        Text(localized("默认 Machine：\(defaultMachineText)", "Default machine: \(defaultMachineText)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
            }
        } else {
            MenuBarPanel(accent: CDTheme.ember) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(CDTheme.ember)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(localized("需要处理 \(issues.count) 项", "\(issues.count) issue(s)"))
                                .font(.callout.weight(.semibold))
                            Text(issues.first ?? runtimeStore.statusTitle(language: language))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                    }

                    if runtimeStore.environment.containerAvailable, !runtimeStore.environment.systemRunning {
                        Button {
                            Task { await runtimeStore.startSystem() }
                        } label: {
                            Label(language.t(.startSystem), systemImage: "play.circle")
                        }
                        .buttonStyle(.borderedProminent)
                        .help(localized("启动 container system", "Start container system"))
                    }
                }
            }
        }
    }

    private var activeTaskCard: some View {
        MenuBarPanel(accent: CDTheme.dockerBlue) {
            HStack(spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(CDTheme.dockerBlue)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(localized("任务运行中", "Tasks running"))
                        .font(.callout.weight(.semibold))
                    Text(localized("\(operationStore.activeCount) 个操作正在执行", "\(operationStore.activeCount) operation(s) in progress"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
        }
    }

    private var resourceGrid: some View {
        MenuBarPanel(accent: CDTheme.dockerBlue) {
            VStack(alignment: .leading, spacing: 10) {
                MenuBarSectionHeader(
                    title: localized("核心数量", "Core counts"),
                    subtitle: localized("容器、Machine、镜像和 Compose", "Containers, machines, images, and Compose"),
                    systemImage: "rectangle.grid.3x2"
                )

                LazyVGrid(columns: metricColumns, spacing: 8) {
                    MenuBarMetricCard(
                        title: language.t(.containers),
                        value: "\(runningContainers)/\(runtimeStore.containers.count)",
                        subtitle: localized("运行 \(runningContainers)，停止 \(stoppedContainers)", "\(runningContainers) running, \(stoppedContainers) stopped"),
                        tint: CDTheme.cyan
                    )
                    MenuBarMetricCard(
                        title: language.t(.machines),
                        value: "\(runningMachines)/\(runtimeStore.machines.count)",
                        subtitle: localized("运行 \(runningMachines)，停止 \(stoppedMachines)", "\(runningMachines) running, \(stoppedMachines) stopped"),
                        tint: CDTheme.dockerBlue
                    )
                    MenuBarMetricCard(
                        title: language.t(.images),
                        value: "\(runtimeStore.images.count)",
                        subtitle: localized("本地镜像", "Local images"),
                        tint: CDTheme.violet
                    )
                    MenuBarMetricCard(
                        title: language.t(.compose),
                        value: "\(composeStore.projects.count)",
                        subtitle: localized("项目", "Projects"),
                        tint: CDTheme.dockerBlue
                    )
                }
            }
        }
    }

    private var recentResourcesCard: some View {
        MenuBarPanel(accent: CDTheme.ember) {
            VStack(alignment: .leading, spacing: 10) {
                MenuBarSectionHeader(
                    title: localized("最近资源", "Recent resources"),
                    subtitle: localized("容器、Machine 和镜像快照", "Containers, machines, and images snapshot"),
                    systemImage: "list.bullet.rectangle"
                )

                VStack(spacing: 0) {
                    if runtimeStore.containers.isEmpty, runtimeStore.machines.isEmpty, runtimeStore.images.isEmpty {
                        Text(localized("暂无本地资源。", "No local resources yet."))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(runtimeStore.containers.prefix(2)) { container in
                            MenuBarResourceRow(
                                systemImage: "shippingbox",
                                title: container.id,
                                subtitle: container.imageName,
                                value: container.state,
                                tint: container.state == "running" ? CDTheme.lime : .secondary
                            )
                            Divider()
                        }
                        ForEach(runtimeStore.machines.prefix(2)) { machine in
                            MenuBarResourceRow(
                                systemImage: "desktopcomputer",
                                title: machine.id,
                                subtitle: "\(machine.cpus) CPU / \(machine.memoryDisplay)",
                                value: machine.statusText,
                                tint: machine.isRunning ? CDTheme.lime : .secondary
                            )
                            Divider()
                        }
                        ForEach(runtimeStore.images.prefix(2)) { image in
                            MenuBarResourceRow(
                                systemImage: "photo.stack",
                                title: image.reference,
                                subtitle: image.createdText,
                                value: image.sizeDisplay,
                                tint: CDTheme.violet
                            )
                            if image.id != runtimeStore.images.prefix(2).last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private func diskCard(_ diskUsage: DiskUsageSummary) -> some View {
        MenuBarPanel(accent: CDTheme.violet) {
            VStack(alignment: .leading, spacing: 9) {
                MenuBarSectionHeader(
                    title: localized("磁盘使用", "Disk usage"),
                    subtitle: localized("总占用 \(diskUsage.totalSizeDisplay)", "Total \(diskUsage.totalSizeDisplay)"),
                    systemImage: "internaldrive"
                )

                HStack {
                    MenuBarKeyValue(title: localized("可回收", "Reclaimable"), value: diskUsage.reclaimableDisplay)
                    Spacer()
                    Text("\(Int((diskReclaimableRatio * 100).rounded()))%")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: diskReclaimableRatio)
                    .tint(CDTheme.violet)
                    .controlSize(.small)

                HStack(spacing: 8) {
                    MenuBarDiskMiniStat(title: "Containers", value: diskUsage.containers.reclaimableDisplay)
                    MenuBarDiskMiniStat(title: "Images", value: diskUsage.images.reclaimableDisplay)
                    MenuBarDiskMiniStat(title: "Volumes", value: diskUsage.volumes.reclaimableDisplay)
                }
            }
        }
    }

    private var composeCard: some View {
        MenuBarPanel(accent: CDTheme.dockerBlue) {
            VStack(alignment: .leading, spacing: 10) {
                MenuBarSectionHeader(
                    title: language.t(.recentCompose),
                    subtitle: "\(composeStore.projects.count) \(localized("个项目", "projects"))",
                    systemImage: "square.stack.3d.up"
                )

                if composeStore.projects.isEmpty {
                    Text(language.t(.noComposeProjects))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(spacing: 0) {
                        ForEach(composeStore.projects.prefix(3)) { project in
                            MenuBarComposeProjectRow(
                                project: project,
                                runtimeSummaries: project.runtimeSummaries(containers: runtimeStore.containers),
                                language: language
                            )
                            if project.id != composeStore.projects.prefix(3).last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private var operationsCard: some View {
        MenuBarPanel(accent: operationStore.activeCount > 0 ? CDTheme.dockerBlue : CDTheme.lime) {
            VStack(alignment: .leading, spacing: 10) {
                MenuBarSectionHeader(
                    title: localized("任务", "Tasks"),
                    subtitle: operationStore.activeCount > 0 ? localized("\(operationStore.activeCount) 个运行中", "\(operationStore.activeCount) running") : localized("最近镜像 / Compose 操作", "Recent image / Compose operations"),
                    systemImage: "checklist"
                )

                VStack(spacing: 0) {
                    ForEach(recentOperations) { record in
                        MenuBarOperationRow(record: record, language: language)
                        if record.id != recentOperations.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var actionsCard: some View {
        MenuBarPanel(accent: CDTheme.cyan) {
            VStack(alignment: .leading, spacing: 10) {
                MenuBarSectionHeader(
                    title: localized("快捷操作", "Quick actions"),
                    subtitle: localized("打开常用页面或控制运行时", "Open pages or control runtime"),
                    systemImage: "bolt.fill"
                )

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    MenuBarActionButton(title: language.t(.dashboard), systemImage: "rectangle.grid.2x2") {
                        openMain(section: .dashboard)
                    }
                    MenuBarActionButton(title: language.t(.containers), systemImage: "shippingbox") {
                        openMain(section: .containers)
                    }
                    MenuBarActionButton(title: language.t(.observability), systemImage: "waveform.path.ecg") {
                        openMain(section: .observability)
                    }
                    MenuBarActionButton(title: language.t(.refresh), systemImage: "arrow.clockwise") {
                        refresh()
                    }
                    MenuBarActionButton(
                        title: runtimeStore.environment.systemRunning ? language.t(.stopSystem) : language.t(.startSystem),
                        systemImage: runtimeStore.environment.systemRunning ? "stop.circle" : "play.circle"
                    ) {
                        toggleSystem()
                    }
                    .disabled(!runtimeStore.environment.containerAvailable)
                    MenuBarActionButton(title: language.t(.settings), systemImage: "gearshape") {
                        openSettings()
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Label(lastUpdatedText, systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label(localized("退出", "Quit"), systemImage: "power")
            }
            .buttonStyle(.plain)
            .help(localized("退出 ContainerDesktop", "Quit ContainerDesktop"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(CDTheme.panelSurface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(CDTheme.separator)
                .frame(height: 1)
        }
    }

    private func refresh() {
        Task {
            await runtimeStore.refreshAll()
            await composeStore.reloadProjects()
            await runtimeStore.refreshResourceMonitorOnce()
        }
    }

    private func toggleSystem() {
        Task {
            if runtimeStore.environment.systemRunning {
                await runtimeStore.stopSystem()
            } else {
                await runtimeStore.startSystem()
            }
            await runtimeStore.refreshResourceMonitorOnce()
        }
    }

    private func openMain(section: AppSection? = nil) {
        if let section {
            selectedSectionRaw = section.rawValue
            ContainerDesktopMainMenuController.shared.updateSelectedSection(section)
        }
        ContainerDesktopMainWindow.activateOrOpen()
    }

    private func openSettings() {
        ContainerDesktopWindowRouter.openSettings()
    }

    private func localized(_ zh: String, _ en: String) -> String {
        language.resolved == .zhHans ? zh : en
    }
}

private struct MenuBarPanel<Content: View>: View {
    var accent: Color
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(CDTheme.panelSurface)
                    Rectangle()
                        .fill(accent)
                        .frame(width: 2)
                        .padding(.vertical, 10)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(CDTheme.hairline)
            }
    }
}

private struct MenuBarStatusOrb: View {
    var systemImage: String
    var tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.30), lineWidth: 1)
                .frame(width: 46, height: 46)
            Circle()
                .stroke(tint.opacity(0.12), lineWidth: 6)
                .frame(width: 38, height: 38)
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(CDTheme.inputSurface, in: Circle())
        }
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
                .shadow(color: tint.opacity(0.75), radius: 5)
                .padding(3)
        }
    }
}

private struct MenuBarCircuitBackdrop: View {
    var tint: Color

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let width = proxy.size.width
                let height = proxy.size.height
                path.move(to: CGPoint(x: width * 0.42, y: height * 0.16))
                path.addLine(to: CGPoint(x: width * 0.58, y: height * 0.16))
                path.addLine(to: CGPoint(x: width * 0.66, y: height * 0.32))
                path.move(to: CGPoint(x: width * 0.74, y: height * 0.28))
                path.addLine(to: CGPoint(x: width * 0.90, y: height * 0.28))
                path.addLine(to: CGPoint(x: width * 0.96, y: height * 0.52))
                path.move(to: CGPoint(x: width * 0.48, y: height * 0.78))
                path.addLine(to: CGPoint(x: width * 0.70, y: height * 0.78))
            }
            .stroke(tint.opacity(0.18), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round, dash: [5, 6]))
        }
        .allowsHitTesting(false)
    }
}

private struct MenuBarSignalPill: View {
    var title: String
    var value: String
    var systemImage: String
    var tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(value)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(CDTheme.inputSurface)
                .overlay(alignment: .bottomLeading) {
                    Rectangle()
                        .fill(tint.opacity(0.72))
                        .frame(width: 34, height: 2)
                        .padding(.leading, 9)
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(tint.opacity(0.22))
        }
    }
}

private struct MenuBarSectionHeader: View {
    var title: String
    var subtitle: String
    var systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CDTheme.dockerBlue)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct MenuBarMetricCard: View {
    var title: String
    var value: String
    var subtitle: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
        .background(CDTheme.inputSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .bottomLeading) {
            Capsule()
                .fill(tint)
                .frame(width: 26, height: 3)
                .padding(.leading, 9)
                .padding(.bottom, 6)
        }
    }
}

private struct MenuBarKeyValue: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.monospacedDigit().weight(.semibold))
        }
    }
}

private struct MenuBarInfoTile: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .background(CDTheme.inputSurface, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct MenuBarResourceRow: View {
    var systemImage: String
    var title: String
    var subtitle: String
    var value: String
    var tint: Color

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            Text(value)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.vertical, 7)
    }
}

private struct MenuBarDiskMiniStat: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CDTheme.inputSurface, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct MenuBarComposeProjectRow: View {
    var project: ComposeProject
    var runtimeSummaries: [ComposeServiceRuntimeSummary]
    var language: AppLanguage

    private var matchedCount: Int {
        runtimeSummaries.reduce(0) { $0 + $1.containers.count }
    }

    private var runningCount: Int {
        runtimeSummaries.reduce(0) { $0 + $1.runningCount }
    }

    private var tint: Color {
        if matchedCount == 0 {
            return .secondary
        }
        if runningCount == matchedCount {
            return CDTheme.lime
        }
        if runningCount == 0 {
            return CDTheme.ember
        }
        return CDTheme.violet
    }

    var body: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(project.path.deletingLastPathComponent().lastPathComponent.nilIfBlank ?? project.path.deletingLastPathComponent().path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(runningCount)/\(max(matchedCount, project.services.count))")
                    .font(.caption.monospacedDigit().weight(.semibold))
                Text(language.resolved == .zhHans ? "运行/服务" : "run/svc")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 7)
    }
}

private struct MenuBarOperationRow: View {
    var record: AppOperationRecord
    var language: AppLanguage

    private var tint: Color {
        switch record.status {
        case .running:
            return CDTheme.dockerBlue
        case .succeeded:
            return CDTheme.lime
        case .failed:
            return CDTheme.ember
        }
    }

    private var symbolName: String {
        switch record.status {
        case .running:
            return "hourglass"
        case .succeeded:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.octagon.fill"
        }
    }

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbolName)
                .foregroundStyle(tint)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(record.target)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(record.status.title(language: language))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
        }
        .padding(.vertical, 7)
    }
}

private struct MenuBarActionButton: View {
    var title: String
    var systemImage: String
    var help: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
        }
        .buttonStyle(.bordered)
        .help(help ?? title)
    }
}
