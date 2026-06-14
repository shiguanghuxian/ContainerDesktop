import SwiftUI

struct ComposeServiceObservationPanel: View {
    @Environment(\.appLanguage) private var language
    var store: ComposeServiceObservationStore

    var body: some View {
        DetailSection(title: language.resolved == .zhHans ? "Compose 观测" : "Compose Observation") {
            if let scopeName = store.selectedServiceName {
                VStack(alignment: .leading, spacing: 12) {
                    DetailInfoCard {
                        HStack(spacing: 10) {
                            Text(scopeName)
                                .font(.callout.weight(.semibold))
                            if store.isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Spacer()
                            Button {
                                store.clear()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .frame(width: 26, height: 26)
                            }
                            .buttonStyle(.plain)
                            .help(language.resolved == .zhHans ? "清空观测结果" : "Clear observation")
                        }

                        DetailInfoRow(
                            title: language.resolved == .zhHans ? "容器" : "Containers",
                            value: store.selectedContainerIDs.isEmpty ? "—" : store.selectedContainerIDs.joined(separator: ", "),
                            monospaced: true
                        )
                        if let summary = store.statsSummary {
                            DetailInfoRow(title: "Memory", value: summary.memoryDisplay)
                            DetailInfoRow(title: "Network", value: summary.networkDisplay)
                            DetailInfoRow(title: "Block I/O", value: summary.blockIODisplay)
                            DetailInfoRow(title: "PIDs", value: "\(summary.totalProcesses)")
                        } else {
                            DetailInfoRow(title: "Stats", value: store.isLoading ? "加载中..." : "—")
                        }
                        DetailInfoRow(
                            title: language.resolved == .zhHans ? "刷新" : "Updated",
                            value: store.lastUpdated?.formatted(date: .abbreviated, time: .shortened) ?? "—"
                        )
                    }

                    if let errorMessage = store.errorMessage?.nilIfBlank {
                        StatusBanner(text: errorMessage, systemImage: "exclamationmark.triangle", tint: CDTheme.ember)
                    }

                    TerminalBlock(text: store.logsText, minHeight: 190)
                }
            } else {
                DetailInfoCard {
                    Text(language.resolved == .zhHans ? "选择项目或服务读取日志和 Stats。" : "Select a project or service to load logs and stats.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
