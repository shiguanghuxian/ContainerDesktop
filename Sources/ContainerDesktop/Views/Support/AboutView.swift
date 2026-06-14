import AppKit
import SwiftUI

struct AboutView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var runtimeStore: RuntimeStore
    @Bindable var composeStore: ComposeProjectStore
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
