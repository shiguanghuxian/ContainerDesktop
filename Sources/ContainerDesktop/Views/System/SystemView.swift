import AppKit
import SwiftUI

struct SystemView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.openWindow) private var openWindow
    @Bindable var runtimeStore: RuntimeStore
    @Bindable var systemConfigStore: SystemConfigStore
    @State private var showPropertiesDrawer = false
    @State private var drawerMode: DetailDrawerMode = .overview

    var body: some View {
        DrawerPageLayout(isDrawerPresented: showPropertiesDrawer) {
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
                        openWindow(id: "settings")
                        NSApp.activate(ignoringOtherApps: true)
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

            PanelView(title: "container config.toml", subtitle: systemConfigStore.configPath, systemImage: "doc.badge.gearshape") {
                HStack(spacing: 12) {
                    Text(language.resolved == .zhHans ? "配置编辑已移到独立设置窗口，避免主窗口和设置窗口重复。" : "Configuration editing lives in the dedicated Settings window to avoid duplicate settings surfaces.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        openWindow(id: "settings")
                        NSApp.activate(ignoringOtherApps: true)
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
