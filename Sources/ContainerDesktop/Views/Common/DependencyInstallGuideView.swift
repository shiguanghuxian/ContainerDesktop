import AppKit
import SwiftUI

struct DependencyInstallGuideView: View {
    @Environment(\.appLanguage) private var language
    var environment: EnvironmentProbe
    var onRefresh: () -> Void

    @State private var installLaunchError: String?

    private var targets: [DependencyInstallTarget] {
        DependencyInstallTarget.missing(in: environment)
    }

    private var allCommands: String {
        targets.map(\.displayCommand).joined(separator: "\n\n")
    }

    var body: some View {
        if !targets.isEmpty {
            PanelView(
                title: localized("环境安装引导", "Environment Setup"),
                subtitle: localized("安装缺失组件后刷新状态", "Install missing components, then refresh status"),
                systemImage: "arrow.down.circle"
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    StatusBanner(
                        text: headerMessage,
                        systemImage: "exclamationmark.triangle",
                        tint: CDTheme.ember
                    )

                    VStack(spacing: 10) {
                        ForEach(targets) { target in
                            dependencyStep(target)
                        }
                    }

                    if let installLaunchError {
                        StatusBanner(text: installLaunchError, systemImage: "exclamationmark.triangle", tint: CDTheme.ember)
                    }

                    HStack(spacing: 10) {
                        Button {
                            openInstallScript()
                        } label: {
                            Label(localized("打开终端安装", "Install in Terminal"), systemImage: "terminal")
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            copy(allCommands)
                        } label: {
                            Label(localized("复制全部命令", "Copy All Commands"), systemImage: "doc.on.doc")
                        }

                        Button {
                            onRefresh()
                        } label: {
                            Label(localized("刷新状态", "Refresh Status"), systemImage: "arrow.clockwise")
                        }

                        Spacer()
                    }
                }
            }
        }
    }

    private var headerMessage: String {
        let names = targets.map { $0.title(language: language) }.joined(separator: " / ")
        return language.resolved == .zhHans
            ? "检测到缺少 \(names)。可以复制命令手动执行，或打开终端运行安装脚本。"
            : "Missing \(names). Copy commands manually, or open Terminal to run the install script."
    }

    private func dependencyStep(_ target: DependencyInstallTarget) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                IconTile(systemImage: target.systemImage, tint: CDTheme.dockerBlue, size: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(target.title(language: language))
                        .font(.callout.weight(.semibold))
                    Text(target.description(language: language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button {
                    copy(target.displayCommand)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .help(localized("复制命令", "Copy command"))

                Link(destination: target.documentationURL) {
                    Image(systemName: "safari")
                }
                .help(localized("打开官方页面", "Open official page"))
            }

            Text(target.displayCommand)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .foregroundStyle(.primary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CDTheme.codeSurface, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(CDTheme.separator)
                }
        }
        .padding(12)
        .background(CDTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }

    private func openInstallScript() {
        installLaunchError = nil
        do {
            try SystemTerminalLauncher.openDependencyInstallScript(targets: targets)
        } catch {
            installLaunchError = error.localizedDescription
        }
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private func localized(_ zh: String, _ en: String) -> String {
        language.resolved == .zhHans ? zh : en
    }
}
