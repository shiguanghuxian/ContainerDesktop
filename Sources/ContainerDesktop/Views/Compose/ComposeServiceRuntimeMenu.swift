import SwiftUI

struct ComposeServiceRuntimeMenu: View {
    @Environment(\.appLanguage) private var language
    var summary: ComposeServiceRuntimeSummary
    var onOpenContainer: (ContainerSummary) -> Void
    var onOpenTerminal: (ComposeServiceRuntimeSummary, ExternalTerminalDestination) -> Void
    var onObserveService: (ComposeServiceRuntimeSummary) -> Void
    var onStartContainers: (ComposeServiceRuntimeSummary) -> Void
    var onStopContainers: (ComposeServiceRuntimeSummary) -> Void
    var onRestartContainers: (ComposeServiceRuntimeSummary) -> Void
    var isBusy = false

    private var hasContainers: Bool {
        !summary.containers.isEmpty
    }

    var body: some View {
        Menu {
            if let container = summary.containers.first {
                Button {
                    onOpenContainer(container)
                } label: {
                    Label(language.resolved == .zhHans ? "打开容器详情" : "Open container details", systemImage: "arrow.up.right.square")
                }
            }

            Menu {
                ExternalTerminalDestinationMenuItems { destination in
                    onOpenTerminal(summary, destination)
                }
            } label: {
                Label(language.resolved == .zhHans ? "打开服务终端" : "Open service terminal", systemImage: "terminal")
            }
            .disabled(summary.primaryRunningContainer == nil)

            Button {
                onObserveService(summary)
            } label: {
                Label(language.resolved == .zhHans ? "读取日志和 Stats" : "Load logs and stats", systemImage: "waveform.path.ecg")
            }

            Divider()

            Button {
                onStartContainers(summary)
            } label: {
                Label(language.resolved == .zhHans ? "启动匹配容器" : "Start matched containers", systemImage: "play.circle")
            }
            .disabled(!hasContainers || isBusy)

            Button {
                onStopContainers(summary)
            } label: {
                Label(language.resolved == .zhHans ? "停止匹配容器" : "Stop matched containers", systemImage: "stop.circle")
            }
            .disabled(!hasContainers || isBusy)

            Button {
                onRestartContainers(summary)
            } label: {
                Label(language.resolved == .zhHans ? "重启匹配容器" : "Restart matched containers", systemImage: "arrow.clockwise.circle")
            }
            .disabled(!hasContainers || isBusy)
        } label: {
            Group {
                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CDTheme.dockerBlue)
                }
            }
            .frame(width: 24, height: 24)
            .background(CDTheme.dockerBlue.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .help(language.resolved == .zhHans ? "服务运行时操作" : "Service runtime actions")
    }
}
