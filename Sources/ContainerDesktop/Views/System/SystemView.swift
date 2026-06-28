import AppKit
import SwiftUI

struct SystemView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var runtimeStore: RuntimeStore
    @Bindable var systemConfigStore: SystemConfigStore
    @State private var showPropertiesDrawer = false
    @State private var drawerMode: DetailDrawerMode = .overview
    @State private var isConfirmingCleanup = false
    @State private var cleanupPlan = SystemCleanupPlan.safeDefault
    @State private var areComponentVersionsExpanded = false
    private let systemDashboardSpacing: CGFloat = 16
    private let systemDashboardColumnMinimumWidth: CGFloat = 320

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
        .alert(cleanupConfirmationTitle, isPresented: $isConfirmingCleanup) {
            Button(cleanupConfirmationActionTitle, role: .destructive) {
                let plan = cleanupPlan
                Task { await runtimeStore.cleanupCache(plan: plan) }
            }
            Button(localized("取消", "Cancel"), role: .cancel) {}
        } message: {
            Text(cleanupConfirmationMessage)
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
            systemDashboardWideLayout
            systemDashboardSingleColumnLayout
        }
    }

    private var systemDashboardWideLayout: some View {
        VStack(alignment: .leading, spacing: systemDashboardSpacing) {
            systemDashboardTopRow
            systemDashboardMiddleRow
            systemDashboardBottomRow
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var systemDashboardTopRow: some View {
        HStack(alignment: .top, spacing: systemDashboardSpacing) {
            environmentPanel
                .frame(minWidth: systemDashboardColumnMinimumWidth, maxWidth: .infinity, alignment: .topLeading)
            componentVersionsPanel
                .frame(minWidth: systemDashboardColumnMinimumWidth, maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var systemDashboardMiddleRow: some View {
        cleanupPanel
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var systemDashboardBottomRow: some View {
        HStack(alignment: .top, spacing: systemDashboardSpacing) {
            configPanel
                .frame(minWidth: systemDashboardColumnMinimumWidth, maxWidth: .infinity, alignment: .topLeading)
            runtimePropertiesPanel
                .frame(minWidth: systemDashboardColumnMinimumWidth, maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var systemDashboardSingleColumnLayout: some View {
        VStack(alignment: .leading, spacing: systemDashboardSpacing) {
            environmentPanel
            componentVersionsPanel
            cleanupPanel
            configPanel
            runtimePropertiesPanel
        }
    }

    private var environmentPanel: some View {
        PanelView(title: language.t(.environment), subtitle: runtimeStore.statusTitle(language: language), systemImage: "desktopcomputer") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(runtimeStore.environment.systemRunning ? localized("引擎运行中", "Engine running") : localized("引擎未运行", "Engine stopped"))
                            .font(.title3.weight(.semibold))
                        Text(environmentSummaryText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    StatusPill(
                        title: runtimeStore.environment.systemRunning ? language.t(.running) : language.t(.systemStopped),
                        systemImage: runtimeStore.environment.systemRunning ? "checkmark.circle" : "stop.circle",
                        tint: runtimeStore.environment.systemRunning ? CDTheme.lime : CDTheme.ember
                    )
                }

                Divider()

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 9) {
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
                }
            }
        }
    }

    private var componentVersionsPanel: some View {
        PanelView(title: localized("组件版本", "Component Versions"), subtitle: componentVersionSubtitle, systemImage: "number") {
            componentVersionHeaderControls
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                Text(localized("检查 CLI 与运行时组件版本，展开后查看来源和升级命令。", "Check CLI and runtime component versions. Expand to inspect sources and upgrade commands."))
                    .font(.callout)
                    .foregroundStyle(.secondary)

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
            plan: $cleanupPlan,
            onCleanup: { isConfirmingCleanup = true }
        )
    }

    private var configPanel: some View {
        SystemActionPanel(
            title: "container config.toml",
            subtitle: systemConfigStore.configPath,
            systemImage: "doc.badge.gearshape",
            message: localized("默认资源、网络和运行时镜像在设置窗口统一管理。", "Manage default resources, network, and runtime images in Settings."),
            actionTitle: language.t(.settings),
            actionSystemImage: "gearshape",
            actionHelp: language.t(.openSettings),
            isProminent: true
        ) {
            ContainerDesktopWindowRouter.openSettings()
        }
    }

    private var runtimePropertiesPanel: some View {
        SystemActionPanel(
            title: language.t(.runtimeProperties),
            subtitle: "container system property list --format json",
            systemImage: "doc.plaintext",
            message: localized("查看解析概览和原始 JSON，用于排查运行时状态。", "Inspect the parsed overview and raw JSON for runtime diagnostics."),
            actionTitle: language.t(.details),
            actionSystemImage: "sidebar.right",
            actionHelp: localized("打开运行时属性抽屉", "Open runtime properties drawer"),
            isProminent: false
        ) {
            showPropertiesDrawer = true
            drawerMode = .overview
        }
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

    private var environmentSummaryText: String {
        if !runtimeStore.environment.containerAvailable {
            return localized("container CLI 缺失，部分功能不可用。", "container CLI is missing; some features are unavailable.")
        }
        if !runtimeStore.environment.systemRunning {
            return localized("启动 system 后可管理本地资源。", "Start the system to manage local resources.")
        }
        return localized("CLI、系统服务和资源刷新已就绪。", "CLI, system service, and resource refresh are ready.")
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private var cleanupConfirmationTitle: String {
        cleanupPlan.includesVolumes
            ? localized("确认清理所选资源？", "Clean selected resources?")
            : localized("安全清理缓存？", "Run safe cleanup?")
    }

    private var cleanupConfirmationActionTitle: String {
        cleanupPlan.includesVolumes
            ? localized("清理所选", "Clean Selected")
            : localized("安全清理", "Safe Cleanup")
    }

    private var cleanupConfirmationMessage: String {
        let names = cleanupPlan.categoryTitles(language: language).joined(separator: localized("、", ", "))
        let estimate = cleanupPlan.estimatedReclaimableDisplay(in: runtimeStore.diskUsage)
        let volumeWarning = cleanupPlan.includesVolumes
            ? localized("包含未使用卷清理；未被容器引用的卷会被删除，请确认这些卷不再保存需要的数据。", "Unused volumes are included. Volumes not referenced by containers will be deleted, so confirm the data is no longer needed.")
            : localized("不会删除卷，也不会删除正在被容器引用的镜像。", "Volumes and images referenced by containers are kept.")
        return localized(
            "将清理：\(names)。当前估算可释放 \(estimate)。\(volumeWarning)",
            "Selected categories: \(names). Estimated reclaimable space: \(estimate). \(volumeWarning)"
        )
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

private struct SystemStatusLine: View {
    var title: String
    var value: String

    var body: some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .monospacedDigit()
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.callout)
    }
}

private struct SystemActionPanel: View {
    var title: String
    var subtitle: String
    var systemImage: String
    var message: String
    var actionTitle: String
    var actionSystemImage: String
    var actionHelp: String
    var isProminent: Bool
    var action: () -> Void

    var body: some View {
        PanelView(title: title, subtitle: subtitle, systemImage: systemImage) {
            ViewThatFits(in: .horizontal) {
                horizontalLayout
                verticalLayout
            }
        }
    }

    private var horizontalLayout: some View {
        HStack(alignment: .center, spacing: 14) {
            messageText
            Spacer(minLength: 12)
            actionButton
        }
        .frame(minHeight: 54, alignment: .center)
    }

    private var verticalLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            messageText
            actionButton
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)
    }

    private var messageText: some View {
        Text(message)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var actionButton: some View {
        Group {
            if isProminent {
                Button(action: action) {
                    Label(actionTitle, systemImage: actionSystemImage)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(action: action) {
                    Label(actionTitle, systemImage: actionSystemImage)
                }
                .buttonStyle(.bordered)
            }
        }
        .help(actionHelp)
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
