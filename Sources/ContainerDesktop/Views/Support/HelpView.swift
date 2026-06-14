import AppKit
import SwiftUI

struct HelpView: View {
    @Environment(\.appLanguage) private var language
    @State private var copiedMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(
                title: language.t(.help),
                subtitle: language.t(.helpSubtitle),
                systemImage: "questionmark.circle"
            ) {
                HStack(spacing: 8) {
                    Link(destination: URL(string: "https://github.com/apple/container")!) {
                        Label(language.resolved == .zhHans ? "Apple container" : "Apple container", systemImage: "safari")
                    }
                    Button {
                        copy("container system status", message: localized("已复制诊断命令", "Diagnostic command copied"))
                    } label: {
                        Label(localized("复制诊断命令", "Copy Diagnostic"), systemImage: "doc.on.doc")
                    }
                }
            }

            if let copiedMessage {
                StatusBanner(text: copiedMessage, systemImage: "checkmark.circle", tint: CDTheme.lime)
                    .frame(maxWidth: 520)
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    quickStartPanel
                        .frame(maxWidth: .infinity)
                    workflowsPanel
                        .frame(maxWidth: .infinity)
                }

                VStack(alignment: .leading, spacing: 16) {
                    quickStartPanel
                    workflowsPanel
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    commandsPanel
                        .frame(maxWidth: .infinity)
                    troubleshootingPanel
                        .frame(maxWidth: .infinity)
                }

                VStack(alignment: .leading, spacing: 16) {
                    commandsPanel
                    troubleshootingPanel
                }
            }
        }
    }

    private var quickStartPanel: some View {
        PanelView(
            title: localized("快速开始", "Quick Start"),
            subtitle: localized("从环境到第一个容器", "From environment to first container"),
            systemImage: "bolt.circle"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                SupportStepRow(
                    index: 1,
                    title: localized("确认运行时就绪", "Confirm runtime readiness"),
                    message: localized("打开 Dashboard 或 System 页面，确认 container CLI 已安装且 system 正在运行。", "Open Dashboard or System and confirm the container CLI is installed and the system service is running.")
                )
                SupportStepRow(
                    index: 2,
                    title: localized("拉取或构建镜像", "Pull or build an image"),
                    message: localized("在 Images 页面使用 Pull、Build、Import 或 Registry 浏览器准备镜像。", "Use Pull, Build, Import, or the Registry Browser on Images to prepare an image.")
                )
                SupportStepRow(
                    index: 3,
                    title: localized("运行并观测", "Run and observe"),
                    message: localized("在 Containers 页面启动容器；进入详情页查看 Logs、Inspect、Exec、Files、Stats。", "Start a container from Containers, then inspect Logs, Inspect, Exec, Files, and Stats from its detail page.")
                )
            }
        }
    }

    private var workflowsPanel: some View {
        PanelView(
            title: localized("核心工作流", "Core Workflows"),
            subtitle: localized("常用页面怎么配合使用", "How the main pages work together"),
            systemImage: "square.stack.3d.up"
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], spacing: 12) {
                SupportFeatureCard(
                    title: localized("容器管理", "Container management"),
                    message: localized("列表行点击进入完整详情；右侧抽屉用于快速查看基础信息。", "Click a row for full details; use the side drawer for quick basic information."),
                    systemImage: "shippingbox",
                    tint: CDTheme.dockerBlue
                )
                SupportFeatureCard(
                    title: localized("镜像与仓库", "Images and registries"),
                    message: localized("Images 管理本地镜像，Registries 管理登录和远程 tag 浏览。", "Images manages local images; Registries handles logins and remote tag browsing."),
                    systemImage: "photo.stack",
                    tint: CDTheme.violet
                )
                SupportFeatureCard(
                    title: localized("观测与日志", "Observability and logs"),
                    message: localized("Observability 集中查看容器日志、boot 日志、系统服务日志和 stats 快照。", "Observability centralizes container logs, boot logs, system service logs, and stats snapshots."),
                    systemImage: "waveform.path.ecg",
                    tint: CDTheme.lime
                )
                SupportFeatureCard(
                    title: localized("Docker 命令迁移", "Docker command migration"),
                    message: localized("Docker 转换页可把常用 docker 命令改写为 apple/container 命令。", "Docker Convert rewrites common Docker commands into apple/container commands."),
                    systemImage: "arrow.left.arrow.right.square",
                    tint: CDTheme.cyan
                )
            }
        }
    }

    private var commandsPanel: some View {
        PanelView(
            title: localized("常用诊断命令", "Common Diagnostic Commands"),
            subtitle: localized("一键复制到终端执行", "Copy and run in Terminal"),
            systemImage: "terminal"
        ) {
            VStack(spacing: 10) {
                SupportCommandRow(title: localized("系统状态", "System status"), command: "container system status") {
                    copy("container system status", message: localized("已复制系统状态命令", "System status command copied"))
                }
                SupportCommandRow(title: localized("磁盘占用", "Disk usage"), command: "container system df") {
                    copy("container system df", message: localized("已复制磁盘命令", "Disk command copied"))
                }
                SupportCommandRow(title: localized("系统日志", "System logs"), command: "container system logs --last 10m") {
                    copy("container system logs --last 10m", message: localized("已复制系统日志命令", "System logs command copied"))
                }
                SupportCommandRow(title: localized("列出容器", "List containers"), command: "container list --all") {
                    copy("container list --all", message: localized("已复制容器列表命令", "Container list command copied"))
                }
            }
        }
    }

    private var troubleshootingPanel: some View {
        PanelView(
            title: localized("排障路径", "Troubleshooting"),
            subtitle: localized("按现象快速定位", "Start from the visible symptom"),
            systemImage: "wrench.and.screwdriver"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                SupportFeatureCard(
                    title: localized("页面数据为空", "Pages show no data"),
                    message: localized("先点刷新；如果仍为空，到 System 检查 container system 是否运行。", "Refresh first. If still empty, open System and check whether container system is running."),
                    systemImage: "arrow.clockwise",
                    tint: CDTheme.dockerBlue
                )
                SupportFeatureCard(
                    title: localized("镜像登录没变化", "Registry login appears unchanged"),
                    message: localized("确认 Registries 列表刷新；Docker Hub 会以 Docker Hub 展示，真实 server 在副标题中。", "Refresh Registries. Docker Hub is displayed as Docker Hub, with the real server in the subtitle."),
                    systemImage: "key.icloud",
                    tint: CDTheme.cyan
                )
                SupportFeatureCard(
                    title: localized("Exec 终端不可用", "Exec terminal unavailable"),
                    message: localized("确认容器运行中且容器内存在 sh；也可以从详情页或列表打开系统默认终端。", "Confirm the container is running and has sh. You can also open the system terminal from the detail page or list."),
                    systemImage: "terminal",
                    tint: CDTheme.ember
                )
            }
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
