import AppKit
import SwiftUI

struct SystemView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var runtimeStore: RuntimeStore
    @Bindable var systemConfigStore: SystemConfigStore
    @State private var showPropertiesDrawer = false
    @State private var drawerMode: DetailDrawerMode = .overview
    @State private var isConfirmingCleanup = false

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
                    versions: runtimeStore.systemVersions,
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
                    Button {
                        ContainerDesktopWindowRouter.openSettings()
                    } label: {
                        Label(language.t(.settings), systemImage: "gearshape")
                    }
                    Button {
                        showPropertiesDrawer = true
                        drawerMode = .overview
                    } label: {
                        Label(language.t(.runtimeProperties), systemImage: "sidebar.right")
                    }
                }
            }

            if !DependencyInstallTarget.missing(in: runtimeStore.environment).isEmpty {
                DependencyInstallGuideView(environment: runtimeStore.environment) {
                    Task { await runtimeStore.refreshAll() }
                }
            }

            HStack(alignment: .top, spacing: 16) {
                PanelView(title: language.t(.environment), subtitle: runtimeStore.statusTitle(language: language), systemImage: "desktopcomputer") {
                    VStack(alignment: .leading, spacing: 10) {
                        SystemStatusLine(title: "macOS", value: runtimeStore.environment.macOSVersion)
                        SystemStatusLine(title: "Architecture", value: runtimeStore.environment.architecture)
                        SystemStatusLine(title: "container", value: runtimeStore.environment.containerAvailable ? "available" : "missing")
                        SystemStatusLine(title: "container-compose", value: runtimeStore.environment.containerComposeAvailable ? "available" : "missing")
                        SystemStatusLine(title: "system", value: runtimeStore.environment.systemRunning ? "running" : "stopped")
                    }
                }
                .frame(maxWidth: .infinity)

                PanelView(title: language.t(.version), subtitle: "container system version", systemImage: "number") {
                    VStack(alignment: .leading, spacing: 10) {
                        if runtimeStore.systemVersions.isEmpty {
                            Text(language.t(.noVersionInfo))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(runtimeStore.systemVersions) { version in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(version.appName)
                                        .font(.headline)
                                    Text(version.version)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Divider()
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }

            SystemCleanupPanel(
                diskUsage: runtimeStore.diskUsage,
                beforeDiskUsage: runtimeStore.cleanupBeforeDiskUsage,
                afterDiskUsage: runtimeStore.cleanupAfterDiskUsage,
                statusMessage: runtimeStore.cleanupStatusMessage,
                isError: runtimeStore.cleanupStatusIsError,
                isRunning: runtimeStore.isCleanupRunning,
                onCleanup: { isConfirmingCleanup = true }
            )

            PanelView(title: "container config.toml", subtitle: systemConfigStore.configPath, systemImage: "doc.badge.gearshape") {
                HStack(spacing: 12) {
                    Text(language.resolved == .zhHans ? "配置编辑已移到独立设置窗口，避免主窗口和设置窗口重复。" : "Configuration editing lives in the dedicated Settings window to avoid duplicate settings surfaces.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        ContainerDesktopWindowRouter.openSettings()
                    } label: {
                        Label(language.t(.settings), systemImage: "gearshape")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            PanelView(title: language.t(.runtimeProperties), subtitle: "container system property list --format json", systemImage: "doc.plaintext") {
                HStack(spacing: 12) {
                    Text(language.resolved == .zhHans ? "运行时属性可在右侧抽屉中查看解析概览和原始 JSON。" : "Runtime properties are available in the details drawer as parsed overview and raw JSON.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        showPropertiesDrawer = true
                        drawerMode = .overview
                    } label: {
                        Label(language.t(.details), systemImage: "sidebar.right")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
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
    var versions: [SystemVersionEntry]
    var configPath: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            DetailSection(title: language.t(.version)) {
                DetailInfoCard {
                    if versions.isEmpty {
                        Text(language.t(.noVersionInfo))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(versions) { version in
                            DetailInfoRow(title: version.appName, value: version.version)
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
