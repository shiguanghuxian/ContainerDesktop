import AppKit
import SwiftUI

struct SystemView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var runtimeStore: RuntimeStore
    @Bindable var systemConfigStore: SystemConfigStore
    @State private var showPropertiesDrawer = false
    @State private var drawerMode: DetailDrawerMode = .overview
    @State private var isConfirmingCleanup = false
    @State private var areComponentVersionsExpanded = false
    private let systemPanelMinimumColumnWidth: CGFloat = 360

    var body: some View {
        DrawerPageLayout(isDrawerPresented: showPropertiesDrawer, onDismiss: {
            showPropertiesDrawer = false
        }) {
            pageContent
        } drawer: {
            DetailDrawer(
                mode: $drawerMode,
                title: language.t(.runtimeProperties),
                subtitle: "container system property list",
                systemImage: "doc.plaintext",
                rawText: systemConfigStore.runtimeProperties?.prettyString ?? "无运行时属性。",
                onClose: {
                    showPropertiesDrawer = false
                }
            ) {
                SystemRuntimeOverview(
                    config: systemConfigStore.config,
                    componentVersions: runtimeStore.componentVersions,
                    configPath: systemConfigStore.configPath
                )
            }
        }
        .alert("安全清理缓存？", isPresented: $isConfirmingCleanup) {
            Button("安全清理", role: .destructive) {
                Task { await runtimeStore.cleanupCache() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将删除已停止的容器和 dangling/无标签镜像。不会删除卷，也不会删除正在被容器引用的镜像。")
        }
    }

    private var pageContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(
                title: language.t(.system),
                subtitle: language.t(.systemSubtitle),
                systemImage: "gearshape.2"
            ) {
                HStack(spacing: 8) {
                    Button {
                        Task { await runtimeStore.refreshAll() }
                    } label: {
                        Label(language.t(.refresh), systemImage: "arrow.clockwise")
                    }
                    .help(language.resolved == .zhHans ? "刷新系统状态" : "Refresh system status")
                    Button {
                        Task {
                            if runtimeStore.environment.systemRunning {
                                await runtimeStore.stopSystem()
                            } else {
                                await runtimeStore.startSystem()
                            }
                        }
                    } label: {
                        Label(runtimeStore.environment.systemRunning ? language.t(.stopSystem) : language.t(.startSystem), systemImage: runtimeStore.environment.systemRunning ? "stop.circle" : "play.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .help(runtimeStore.environment.systemRunning ? language.t(.stopSystem) : language.t(.startSystem))
                    Button {
                        ContainerDesktopWindowRouter.openSettings()
                    } label: {
                        Label(language.t(.settings), systemImage: "gearshape")
                    }
                    .help(language.t(.openSettings))
                    Button {
                        showPropertiesDrawer = true
                        drawerMode = .overview
                    } label: {
                        Label(language.t(.runtimeProperties), systemImage: "sidebar.right")
                    }
                    .help(language.resolved == .zhHans ? "打开运行时属性抽屉" : "Open runtime properties drawer")
                }
            }

            if !DependencyInstallTarget.missing(in: runtimeStore.environment).isEmpty {
                DependencyInstallGuideView(environment: runtimeStore.environment) {
                    Task { await runtimeStore.refreshAll() }
                }
            }

            systemPanels
        }
    }

    private var systemPanels: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    environmentPanel
                    cleanupPanel
                    configPanel
                    runtimePropertiesPanel
                }
                .frame(minWidth: systemPanelMinimumColumnWidth, maxWidth: .infinity, alignment: .topLeading)

                componentVersionsPanel
                    .frame(minWidth: systemPanelMinimumColumnWidth, maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 16) {
                environmentPanel
                componentVersionsPanel
                cleanupPanel
                configPanel
                runtimePropertiesPanel
            }
        }
    }

    private var environmentPanel: some View {
        PanelView(title: language.t(.environment), subtitle: runtimeStore.statusTitle(language: language), systemImage: "desktopcomputer") {
            VStack(alignment: .leading, spacing: 10) {
                SystemStatusLine(title: "macOS", value: runtimeStore.environment.macOSVersion)
                SystemStatusLine(title: "Architecture", value: runtimeStore.environment.architecture)
                SystemStatusLine(
                    title: "container",
                    value: environmentComponentValue(
                        id: ComponentVersionIDs.container,
                        available: runtimeStore.environment.containerAvailable,
                        rawVersion: runtimeStore.environment.containerVersion
                    )
                )
                SystemStatusLine(
                    title: "container-compose",
                    value: environmentComponentValue(
                        id: ComponentVersionIDs.containerCompose,
                        available: runtimeStore.environment.containerComposeAvailable,
                        rawVersion: runtimeStore.environment.containerComposeVersion
                    )
                )
                SystemStatusLine(title: "system", value: runtimeStore.environment.systemRunning ? "running" : "stopped")
            }
        }
    }

    private var componentVersionsPanel: some View {
        PanelView(title: localized("组件版本", "Component Versions"), subtitle: componentVersionSubtitle, systemImage: "number") {
            VStack(alignment: .leading, spacing: 12) {
                componentVersionCheckHeader

                if let message = runtimeStore.componentVersionErrorMessage?.nilIfBlank {
                    StatusBanner(text: message, systemImage: "exclamationmark.triangle", tint: CDTheme.ember)
                }

                if runtimeStore.componentVersions.isEmpty {
                    Text(language.t(.noVersionInfo))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(runtimeStore.componentVersions) { component in
                        ComponentVersionRow(component: component, isExpanded: areComponentVersionsExpanded) { command in
                            copyToPasteboard(command)
                        }
                    }
                }
            }
        }
    }

    private var componentVersionCheckHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                componentVersionCheckDescription
                Spacer()
                componentVersionHeaderControls
            }

            VStack(alignment: .leading, spacing: 10) {
                componentVersionCheckDescription
                componentVersionHeaderControls
            }
        }
    }

    private var componentVersionCheckDescription: some View {
        Text(localized("检查 container、container-compose 与运行时组件的最新版本。", "Check the latest versions for container, container-compose, and runtime components."))
            .font(.callout)
            .foregroundStyle(.secondary)
    }

    private var componentVersionHeaderControls: some View {
        HStack(spacing: 8) {
            componentVersionExpandButton
            componentVersionCheckButton
        }
    }

    private var componentVersionExpandButton: some View {
        Button {
            withAnimation(.snappy(duration: 0.18)) {
                areComponentVersionsExpanded.toggle()
            }
        } label: {
            Label(
                areComponentVersionsExpanded ? localized("收起详情", "Collapse Details") : localized("展开详情", "Expand Details"),
                systemImage: areComponentVersionsExpanded ? "chevron.up" : "chevron.down"
            )
        }
        .buttonStyle(CDSecondaryButtonStyle())
        .disabled(runtimeStore.componentVersions.isEmpty)
        .help(areComponentVersionsExpanded ? localized("收起组件版本详情", "Collapse component version details") : localized("展开组件版本详情", "Expand component version details"))
    }

    private var componentVersionCheckButton: some View {
        Button {
            Task { await runtimeStore.checkComponentLatestVersions() }
        } label: {
            if runtimeStore.isCheckingComponentVersions {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(localized("检查中", "Checking"))
                }
            } else {
                Label(localized("检查组件更新", "Check Components"), systemImage: "arrow.clockwise")
            }
        }
        .buttonStyle(CDSecondaryButtonStyle())
        .disabled(runtimeStore.isCheckingComponentVersions)
        .help(localized("手动检查组件最新版本", "Manually check component latest versions"))
    }

    private var cleanupPanel: some View {
        SystemCleanupPanel(
            diskUsage: runtimeStore.diskUsage,
            beforeDiskUsage: runtimeStore.cleanupBeforeDiskUsage,
            afterDiskUsage: runtimeStore.cleanupAfterDiskUsage,
            statusMessage: runtimeStore.cleanupStatusMessage,
            isError: runtimeStore.cleanupStatusIsError,
            isRunning: runtimeStore.isCleanupRunning,
            onCleanup: { isConfirmingCleanup = true }
        )
    }

    private var configPanel: some View {
        PanelView(title: "container config.toml", subtitle: systemConfigStore.configPath, systemImage: "doc.badge.gearshape") {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    configPanelDescription
                    Spacer()
                    settingsButton
                }

                VStack(alignment: .leading, spacing: 12) {
                    configPanelDescription
                    settingsButton
                }
            }
        }
    }

    private var configPanelDescription: some View {
        Text(language.resolved == .zhHans ? "配置编辑已移到独立设置窗口，避免主窗口和设置窗口重复。" : "Configuration editing lives in the dedicated Settings window to avoid duplicate settings surfaces.")
            .font(.callout)
            .foregroundStyle(.secondary)
    }

    private var settingsButton: some View {
        Button {
            ContainerDesktopWindowRouter.openSettings()
        } label: {
            Label(language.t(.settings), systemImage: "gearshape")
        }
        .buttonStyle(.borderedProminent)
        .help(language.t(.openSettings))
    }

    private var runtimePropertiesPanel: some View {
        PanelView(title: language.t(.runtimeProperties), subtitle: "container system property list --format json", systemImage: "doc.plaintext") {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    runtimePropertiesDescription
                    Spacer()
                    runtimePropertiesButton
                }

                VStack(alignment: .leading, spacing: 12) {
                    runtimePropertiesDescription
                    runtimePropertiesButton
                }
            }
        }
    }

    private var runtimePropertiesDescription: some View {
        Text(language.resolved == .zhHans ? "运行时属性可在右侧抽屉中查看解析概览和原始 JSON。" : "Runtime properties are available in the details drawer as parsed overview and raw JSON.")
            .font(.callout)
            .foregroundStyle(.secondary)
    }

    private var runtimePropertiesButton: some View {
        Button {
            showPropertiesDrawer = true
            drawerMode = .overview
        } label: {
            Label(language.t(.details), systemImage: "sidebar.right")
        }
        .buttonStyle(.borderedProminent)
        .help(language.resolved == .zhHans ? "打开运行时属性抽屉" : "Open runtime properties drawer")
    }

    private var componentVersionSubtitle: String {
        guard let date = runtimeStore.componentVersionsLastCheckedAt else {
            return localized("手动检查最新版本", "Manual latest-version check")
        }
        return localized(
            "上次检查 \(date.formatted(date: .omitted, time: .shortened))",
            "Last checked \(date.formatted(date: .omitted, time: .shortened))"
        )
    }

    private func environmentComponentValue(id: String, available: Bool, rawVersion: String?) -> String {
        if let component = runtimeStore.componentVersions.first(where: { $0.id == id }) {
            return component.currentVersionDisplay
        }
        guard available else { return "missing" }
        return ComponentVersionParser.displayVersion(from: rawVersion) ?? "available"
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func localized(_ zh: String, _ en: String) -> String {
        language.resolved == .zhHans ? zh : en
    }
}

private struct ComponentVersionRow: View {
    @Environment(\.appLanguage) private var language
    var component: ComponentVersionItem
    var isExpanded: Bool
    var onCopyCommand: (String) -> Void

    var body: some View {
        Group {
            if isExpanded {
                expandedCard
            } else {
                compactRow
            }
        }
    }

    private var compactRow: some View {
        ViewThatFits(in: .horizontal) {
            compactSingleLineRow
            compactWrappedRow
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(CDTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.hairline)
        }
    }

    private var compactSingleLineRow: some View {
        HStack(spacing: 8) {
            Text(component.name)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            ComponentVersionInlineValue(title: localized("当前", "Current"), value: component.currentVersionDisplay)
            ComponentVersionInlineValue(title: localized("最新", "Latest"), value: component.latestVersionDisplay)

            StatusPill(
                title: component.status.title(language: language),
                systemImage: statusIcon,
                tint: statusTint
            )
        }
    }

    private var compactWrappedRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(component.name)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 8)

                StatusPill(
                    title: component.status.title(language: language),
                    systemImage: statusIcon,
                    tint: statusTint
                )
            }

            HStack(spacing: 8) {
                ComponentVersionInlineValue(title: localized("当前", "Current"), value: component.currentVersionDisplay)
                ComponentVersionInlineValue(title: localized("最新", "Latest"), value: component.latestVersionDisplay)
            }
        }
    }

    private var expandedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(component.name)
                        .font(.headline.weight(.semibold))
                    Text(component.sourceDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                StatusPill(
                    title: component.status.title(language: language),
                    systemImage: statusIcon,
                    tint: statusTint
                )
            }

            HStack(spacing: 10) {
                ComponentVersionValue(title: localized("当前", "Current"), value: component.currentVersionDisplay)
                ComponentVersionValue(title: localized("最新", "Latest"), value: component.latestVersionDisplay)
            }

            HStack(spacing: 8) {
                if let latestVersionSource = component.latestVersionSource {
                    Text(latestVersionSource)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(localized("点击检查后显示最新版本。", "Latest version appears after checking."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let releaseURL = component.releaseURL {
                    Button {
                        NSWorkspace.shared.open(releaseURL)
                    } label: {
                        Label(localized("打开", "Open"), systemImage: "safari")
                    }
                    .buttonStyle(CDSecondaryButtonStyle())
                    .help(localized("打开组件发布页或主页", "Open the component release page or homepage"))
                }

                if component.status == .updateAvailable, let command = component.upgradeCommand?.nilIfBlank {
                    Button {
                        onCopyCommand(command)
                    } label: {
                        Label(localized("复制升级命令", "Copy Upgrade Command"), systemImage: "doc.on.doc")
                    }
                    .buttonStyle(CDSecondaryButtonStyle())
                    .help(localized("复制建议升级命令", "Copy the suggested upgrade command"))
                }
            }
        }
        .padding(12)
        .background(CDTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }

    private var statusIcon: String {
        switch component.status {
        case .missing:
            "xmark.circle"
        case .unchecked:
            "questionmark.circle"
        case .upToDate:
            "checkmark.circle"
        case .updateAvailable:
            "arrow.up.circle"
        case .unableToCompare:
            "exclamationmark.triangle"
        }
    }

    private var statusTint: Color {
        switch component.status {
        case .missing, .unableToCompare:
            CDTheme.ember
        case .unchecked:
            CDTheme.dockerBlue
        case .upToDate:
            CDTheme.lime
        case .updateAvailable:
            CDTheme.violet
        }
    }

    private func localized(_ zh: String, _ en: String) -> String {
        language.resolved == .zhHans ? zh : en
    }
}

private struct ComponentVersionInlineValue: View {
    var title: String
    var value: String

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.74)
        }
        .padding(.horizontal, 7)
        .frame(width: 82, height: 26)
        .background(CDTheme.inputSurface, in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(CDTheme.hairline)
        }
    }
}

private struct ComponentVersionValue: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CDTheme.inputSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.hairline)
        }
    }
}

private struct SystemCleanupPanel: View {
    @Environment(\.appLanguage) private var language
    var diskUsage: DiskUsageSummary?
    var beforeDiskUsage: DiskUsageSummary?
    var afterDiskUsage: DiskUsageSummary?
    var statusMessage: String?
    var isError: Bool
    var isRunning: Bool
    var onCleanup: () -> Void

    var body: some View {
        PanelView(
            title: localized("缓存清理", "Cache Cleanup"),
            subtitle: "container prune + container image prune",
            systemImage: "trash"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                if let diskUsage {
                    HStack(spacing: 12) {
                        CleanupMetricTile(title: localized("总占用", "Total"), value: diskUsage.totalSizeDisplay)
                        CleanupMetricTile(title: localized("可回收", "Reclaimable"), value: diskUsage.reclaimableDisplay)
                        CleanupMetricTile(title: localized("容器可回收", "Containers"), value: diskUsage.containers.reclaimableDisplay)
                        CleanupMetricTile(title: localized("镜像可回收", "Images"), value: diskUsage.images.reclaimableDisplay)
                    }
                } else {
                    Text(localized("暂无磁盘使用数据，刷新后可查看可回收空间。", "Disk usage is unavailable. Refresh to inspect reclaimable space."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

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

                HStack(spacing: 12) {
                    Text(localized(
                        "安全清理只删除已停止容器和 dangling/无标签镜像，不删除卷或已被容器引用的镜像。",
                        "Safe cleanup removes stopped containers and dangling images only. Volumes and images referenced by containers are kept."
                    ))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                    Spacer()

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
                            Label(localized("安全清理", "Safe Cleanup"), systemImage: "sparkles")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning)
                    .help(localized("安全清理缓存和未使用资源", "Safely clean caches and unused resources"))
                }
            }
        }
    }

    private func localized(_ zh: String, _ en: String) -> String {
        language.resolved == .zhHans ? zh : en
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

private struct SystemStatusLine: View {
    var title: String
    var value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
                .lineLimit(1)
        }
        .font(.callout)
    }
}

private struct SystemRuntimeOverview: View {
    @Environment(\.appLanguage) private var language
    var config: SystemConfig
    var componentVersions: [ComponentVersionItem]
    var configPath: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            DetailSection(title: language.t(.version)) {
                DetailInfoCard {
                    if componentVersions.isEmpty {
                        Text(language.t(.noVersionInfo))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(componentVersions) { component in
                            DetailInfoRow(title: component.name, value: component.currentVersionDisplay)
                        }
                    }
                }
            }

            DetailSection(title: "config.toml") {
                DetailInfoCard {
                    DetailInfoRow(title: language.t(.configPath), value: configPath)
                    DetailInfoRow(title: language.t(.builder), value: "\(config.build.cpus) CPU / \(config.build.memory)")
                    DetailInfoRow(title: language.t(.containerDefaults), value: "\(config.container.cpus) CPU / \(config.container.memory)")
                    DetailInfoRow(title: language.t(.machine), value: "\(config.machine.cpus.map(String.init) ?? "auto") CPU / \(config.machine.memory ?? "auto")")
                    DetailInfoRow(title: language.t(.registries), value: config.registry.domain)
                    DetailInfoRow(title: language.t(.runtime), value: config.vminit.image)
                }
            }

            DetailSection(title: language.t(.networkSettings)) {
                DetailInfoCard {
                    DetailInfoRow(title: "DNS", value: config.dns.domain ?? "—")
                    DetailInfoRow(title: "IPv4", value: config.network.subnet ?? "—", monospaced: true)
                    DetailInfoRow(title: "IPv6", value: config.network.subnetv6 ?? "—", monospaced: true)
                }
            }
        }
    }
}
