import SwiftUI

struct ComposeTasksDrawer: View {
    @Environment(\.appLanguage) private var language
    var operationStore: AppOperationStore
    var statusMessage: String?
    var statusIsError = false
    var lastOutput: String
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let statusMessage {
                        StatusBanner(
                            text: statusMessage,
                            systemImage: statusIsError ? "exclamationmark.triangle" : "checkmark.circle",
                            tint: statusIsError ? CDTheme.ember : CDTheme.lime
                        )
                    }

                    OperationHistoryPanel(
                        store: operationStore,
                        domains: [.compose],
                        title: language.resolved == .zhHans ? "Compose 任务" : "Compose Tasks",
                        limit: 20
                    )

                    DetailSection(title: language.t(.commandOutput)) {
                        TerminalBlock(text: lastOutput, minHeight: 220)
                    }
                }
                .padding(16)
            }
            .thinScrollBars()
        }
        .frame(width: 620)
        .frame(maxHeight: .infinity)
        .background(CDTheme.panelSurface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(CDTheme.dockerBlue.opacity(0.55))
                .frame(width: 1)
        }
        .shadow(color: Color.black.opacity(0.16), radius: 22, x: -8, y: 0)
    }

    private var header: some View {
        HStack(spacing: 12) {
            IconTile(systemImage: "clock.arrow.circlepath", tint: CDTheme.dockerBlue, size: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(language.resolved == .zhHans ? "Compose 任务" : "Compose Tasks")
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                Text(language.resolved == .zhHans ? "最近 Compose 操作与命令输出" : "Recent Compose operations and command output")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button(action: onClose) {
                Label(language.resolved == .zhHans ? "关闭" : "Close", systemImage: "xmark")
                    .font(.caption.weight(.semibold))
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 9)
                    .frame(height: 28)
                    .background(CDTheme.inputSurface, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(CDTheme.separator)
                    }
            }
            .buttonStyle(.plain)
            .help(language.resolved == .zhHans ? "关闭任务列表" : "Close tasks")
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(16)
    }
}
