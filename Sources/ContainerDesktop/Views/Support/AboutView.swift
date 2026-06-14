import AppKit
import SwiftUI

struct AboutView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var runtimeStore: RuntimeStore
    @Bindable var composeStore: ComposeProjectStore
    @Bindable var appUpdateStore: AppUpdateStore
    @State private var copiedMessage: String?

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        if let version, let build {
            return "\(version) (\(build))"
        }
        return version ?? build ?? "Debug"
    }

    private var runtimeVersion: String {
        runtimeStore.systemVersions.first { $0.appName.localizedCaseInsensitiveContains("container") }?.version
            ?? runtimeStore.systemVersions.first?.version
            ?? "—"
    }

    private var runningContainers: Int {
        runtimeStore.containers.filter { $0.state == "running" }.count
    }

    private var runningMachines: Int {
        runtimeStore.machines.filter(\.isRunning).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(
                title: language.t(.about),
                subtitle: language.t(.aboutSubtitle),
                systemImage: "info.circle"
            ) {
                HStack(spacing: 8) {
                    Button {
                        copy(environmentSummary, message: localized("环境信息已复制", "Environment copied"))
                    } label: {
                        Label(localized("复制环境信息", "Copy Environment"), systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderedProminent)

                    Link(destination: URL(string: "https://github.com/apple/container")!) {
                        Label("apple/container", systemImage: "safari")
                    }
                }
            }

            if let copiedMessage {
                StatusBanner(text: copiedMessage, systemImage: "checkmark.circle", tint: CDTheme.lime)
                    .frame(maxWidth: 520)
            }

            heroPanel
            softwareUpdatePanel

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    runtimePanel
                        .frame(maxWidth: .infinity)
                    scopePanel
                        .frame(maxWidth: .infinity)
                }

                VStack(alignment: .leading, spacing: 16) {
                    runtimePanel
                    scopePanel
                }
            }
        }
        .task {
            if runtimeStore.lastUpdated == nil {
                await runtimeStore.refreshAll()
            }
        }
    }

    private var softwareUpdatePanel: some View {
        PanelView(
            title: localized("软件更新", "Software Update"),
            subtitle: "appcast.json",
            systemImage: "arrow.down.app"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    StatusPill(
                        title: updateStatusPillText,
                        systemImage: updateStatusSystemImage,
                        tint: updateStatusTint
                    )
                    Spacer()
                    Toggle(localized("每天自动检查", "Check daily"), isOn: Binding(
                        get: { appUpdateStore.automaticChecksEnabled },
                        set: { appUpdateStore.automaticChecksEnabled = $0 }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }

                Text(updateSummaryText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                    SupportInfoMetric(title: localized("当前版本", "Current Version"), value: appUpdateStore.currentVersionText, systemImage: "app.badge")
                    SupportInfoMetric(title: localized("最新版本", "Latest Version"), value: appUpdateStore.latestVersionText, systemImage: "number", tint: CDTheme.cyan)
                    SupportInfoMetric(title: localized("更新源", "Update Feed"), value: "appcast.json", systemImage: "link", tint: CDTheme.violet)
                }

                if case .downloading(_, let progress) = appUpdateStore.status {
                    if let progress {
                        ProgressView(value: progress)
                    } else {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                HStack(spacing: 8) {
                    Button {
                        Task { await appUpdateStore.runPrimaryAction() }
                    } label: {
                        if updateIsBusy {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text(updatePrimaryActionTitle)
                            }
                        } else {
                            Label(updatePrimaryActionTitle, systemImage: updatePrimaryActionSystemImage)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!appUpdateStore.canRunPrimaryAction)

                    Button {
                        appUpdateStore.openReleasePage()
                    } label: {
                        Label(localized("打开发布页", "Open Release Page"), systemImage: "safari")
                    }
                }

                if let releaseNotes = appUpdateStore.releaseNotesPreview {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localized("发布说明", "Release Notes"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(releaseNotes)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CDTheme.inputSurface, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(CDTheme.separator)
                    }
                }
            }
        }
    }

    private var heroPanel: some View {
        PanelView(
            title: "ContainerDesktop",
            subtitle: localized("面向 apple/container 的桌面控制台", "Desktop console for apple/container"),
            systemImage: "shippingbox.fill"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Text(localized(
                    "ContainerDesktop 聚合容器、Machine、镜像、网络、存储卷、Compose、观测和 Registry 登录等常用工作流，让 apple/container 的日常操作更接近桌面软件体验。",
                    "ContainerDesktop brings containers, machines, images, networks, volumes, Compose, observability, and registry logins into a desktop workflow for apple/container."
                ))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                    SupportInfoMetric(title: localized("应用版本", "App version"), value: appVersion, systemImage: "app.badge")
                    SupportInfoMetric(title: "container", value: runtimeStore.environment.containerAvailable ? localized("已安装", "Available") : localized("缺失", "Missing"), systemImage: "terminal", tint: runtimeStore.environment.containerAvailable ? CDTheme.lime : CDTheme.ember)
                    SupportInfoMetric(title: "System", value: runtimeStore.environment.systemRunning ? localized("运行中", "Running") : localized("未运行", "Stopped"), systemImage: runtimeStore.environment.systemRunning ? "bolt.fill" : "bolt.slash", tint: runtimeStore.environment.systemRunning ? CDTheme.lime : CDTheme.ember)
                    SupportInfoMetric(title: localized("运行时版本", "Runtime version"), value: runtimeVersion, systemImage: "number")
                }
            }
        }
    }

    private var runtimePanel: some View {
        PanelView(
            title: localized("当前环境", "Current Environment"),
            subtitle: localized("来自本机运行时快照", "From the local runtime snapshot"),
            systemImage: "gauge.with.dots.needle.bottom.50percent"
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                SupportInfoMetric(title: language.t(.containers), value: "\(runningContainers)/\(runtimeStore.containers.count)", systemImage: "shippingbox", tint: CDTheme.dockerBlue)
                SupportInfoMetric(title: language.t(.machines), value: "\(runningMachines)/\(runtimeStore.machines.count)", systemImage: "desktopcomputer", tint: CDTheme.cyan)
                SupportInfoMetric(title: language.t(.images), value: "\(runtimeStore.images.count)", systemImage: "photo.stack", tint: CDTheme.violet)
                SupportInfoMetric(title: language.t(.volumes), value: "\(runtimeStore.volumes.count)", systemImage: "externaldrive", tint: CDTheme.lime)
                SupportInfoMetric(title: language.t(.networks), value: "\(runtimeStore.networks.count)", systemImage: "network", tint: CDTheme.ember)
                SupportInfoMetric(title: language.t(.compose), value: "\(composeStore.projects.count)", systemImage: "square.stack.3d.up", tint: CDTheme.dockerBlue)
            }
        }
    }

    private var scopePanel: some View {
        PanelView(
            title: localized("设计边界", "Product Scope"),
            subtitle: localized("这个工具负责什么、不负责什么", "What the app does and does not do"),
            systemImage: "checklist.checked"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                SupportFeatureCard(
                    title: localized("不保存敏感凭据", "No credential storage"),
                    message: localized("Registry 登录仍交给 container CLI 和 macOS 钥匙串，应用不保存密码。", "Registry credentials are handled by the container CLI and macOS Keychain. The app does not save passwords."),
                    systemImage: "lock.shield",
                    tint: CDTheme.lime
                )
                SupportFeatureCard(
                    title: localized("优先使用官方 CLI", "CLI-first behavior"),
                    message: localized("资源操作最终映射到 container / container-compose 命令，方便排障和迁移。", "Resource actions map back to container / container-compose commands for transparent troubleshooting and migration."),
                    systemImage: "terminal",
                    tint: CDTheme.dockerBlue
                )
                SupportFeatureCard(
                    title: localized("安全优先的清理策略", "Safety-first cleanup"),
                    message: localized("缓存清理默认只清停止容器和 dangling 镜像，不删除 volume。", "Cache cleanup prunes stopped containers and dangling images by default, without deleting volumes."),
                    systemImage: "sparkles",
                    tint: CDTheme.cyan
                )
            }
        }
    }

    private var environmentSummary: String {
        """
        ContainerDesktop: \(appVersion)
        container CLI: \(runtimeStore.environment.containerAvailable ? "available" : "missing")
        container-compose: \(runtimeStore.environment.containerComposeAvailable ? "available" : "missing")
        system running: \(runtimeStore.environment.systemRunning)
        runtime version: \(runtimeVersion)
        containers: \(runningContainers)/\(runtimeStore.containers.count)
        machines: \(runningMachines)/\(runtimeStore.machines.count)
        images: \(runtimeStore.images.count)
        volumes: \(runtimeStore.volumes.count)
        networks: \(runtimeStore.networks.count)
        compose projects: \(composeStore.projects.count)
        """
    }

    private var updateSummaryText: String {
        switch appUpdateStore.status {
        case .idle:
            return localized(
                "从自定义 appcast 检查 ContainerDesktop 新版本。",
                "Check the custom appcast feed for a newer ContainerDesktop release."
            )
        case .checking:
            return localized("正在检查最新版本…", "Checking for updates...")
        case .upToDate(let release):
            return localized(
                "当前已是最新版本。最新版本为 \(release.versionText)。",
                "You are running the latest version. Latest version: \(release.versionText)."
            )
        case .updateAvailable(let package):
            return localized(
                "发现新版本 \(package.versionText)，下载包 \(package.asset.formattedSize)。",
                "Version \(package.versionText) is available. Package size: \(package.asset.formattedSize)."
            )
        case .downloading(_, let progress):
            if let progress {
                return localized("正在下载更新 \(Int(progress * 100))%…", "Downloading update \(Int(progress * 100))%...")
            }
            return localized("正在下载更新…", "Downloading update...")
        case .readyToInstall(let downloaded):
            return localized(
                "新版本 \(downloaded.package.versionText) 已下载，安装会退出并重新打开应用。",
                "Version \(downloaded.package.versionText) is downloaded. Installing will quit and relaunch the app."
            )
        case .installing(let package):
            return localized("正在准备安装 \(package.versionText)…", "Preparing to install \(package.versionText)...")
        case .failed(let message):
            return message
        }
    }

    private var updatePrimaryActionTitle: String {
        switch appUpdateStore.status {
        case .checking:
            return localized("检查中", "Checking")
        case .updateAvailable:
            return localized("下载并安装", "Download & Install")
        case .downloading:
            return localized("下载中", "Downloading")
        case .readyToInstall:
            return localized("安装并重启", "Install & Relaunch")
        case .installing:
            return localized("安装中", "Installing")
        case .idle, .upToDate, .failed:
            return localized("检查更新", "Check for Updates")
        }
    }

    private var updatePrimaryActionSystemImage: String {
        switch appUpdateStore.status {
        case .readyToInstall:
            return "arrow.clockwise.circle"
        case .updateAvailable:
            return "arrow.down.circle"
        default:
            return "arrow.clockwise"
        }
    }

    private var updateStatusPillText: String {
        switch appUpdateStore.status {
        case .idle:
            return localized("未检查", "Idle")
        case .checking:
            return localized("检查中", "Checking")
        case .upToDate:
            return localized("已是最新", "Current")
        case .updateAvailable:
            return localized("有新版本", "Update Available")
        case .downloading:
            return localized("下载中", "Downloading")
        case .readyToInstall:
            return localized("待安装", "Ready")
        case .installing:
            return localized("安装中", "Installing")
        case .failed:
            return localized("失败", "Failed")
        }
    }

    private var updateStatusSystemImage: String {
        switch appUpdateStore.status {
        case .idle:
            return "clock"
        case .checking, .downloading, .installing:
            return "hourglass"
        case .upToDate:
            return "checkmark.circle"
        case .updateAvailable, .readyToInstall:
            return "arrow.down.circle"
        case .failed:
            return "exclamationmark.triangle"
        }
    }

    private var updateStatusTint: Color {
        switch appUpdateStore.status {
        case .idle:
            return .secondary
        case .checking, .downloading, .installing:
            return CDTheme.cyan
        case .upToDate, .readyToInstall:
            return CDTheme.lime
        case .updateAvailable:
            return CDTheme.dockerBlue
        case .failed:
            return CDTheme.ember
        }
    }

    private var updateIsBusy: Bool {
        switch appUpdateStore.status {
        case .checking, .downloading, .installing:
            return true
        case .idle, .upToDate, .updateAvailable, .readyToInstall, .failed:
            return false
        }
    }

    private func copy(_ value: String, message: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        copiedMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            if copiedMessage == message {
                copiedMessage = nil
            }
        }
    }

    private func localized(_ zh: String, _ en: String) -> String {
        language.resolved == .zhHans ? zh : en
    }
}
