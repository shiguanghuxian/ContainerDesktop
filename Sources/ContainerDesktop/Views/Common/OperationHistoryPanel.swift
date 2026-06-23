import AppKit
import SwiftUI

private enum OperationHistoryStatusFilter: String, CaseIterable, Identifiable {
    case all
    case running
    case failed
    case succeeded

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .all:
            language.resolved == .zhHans ? "全部" : "All"
        case .running:
            language.resolved == .zhHans ? "运行中" : "Running"
        case .failed:
            language.resolved == .zhHans ? "失败" : "Failed"
        case .succeeded:
            language.resolved == .zhHans ? "成功" : "Succeeded"
        }
    }

    func includes(_ status: AppOperationStatus) -> Bool {
        switch self {
        case .all:
            true
        case .running:
            status == .running
        case .failed:
            status == .failed
        case .succeeded:
            status == .succeeded
        }
    }
}

struct OperationHistoryPanel: View {
    @Environment(\.appLanguage) private var language
    var store: AppOperationStore
    var domains: Set<AppOperationDomain>
    var title: String
    var limit = 5
    @State private var searchText = ""
    @State private var statusFilter: OperationHistoryStatusFilter = .all

    private var records: [AppOperationRecord] {
        let query = searchText.trimmed.lowercased()
        return store.recent(domains: domains, limit: limit)
            .filter { statusFilter.includes($0.status) }
            .filter { record in
                query.isEmpty
                    || record.title.lowercased().contains(query)
                    || record.target.lowercased().contains(query)
                    || record.commandPreview.lowercased().contains(query)
                    || record.output.lowercased().contains(query)
            }
    }

    var body: some View {
        PanelView(title: title, subtitle: language.resolved == .zhHans ? "最近操作与输出摘要" : "Recent operations and output", systemImage: "clock.arrow.circlepath") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    TextField(language.resolved == .zhHans ? "搜索命令或输出" : "Search commands or output", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                    Picker("", selection: $statusFilter) {
                        ForEach(OperationHistoryStatusFilter.allCases) { filter in
                            Text(filter.title(language: language)).tag(filter)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 120)
                }

                if records.isEmpty {
                    Text(language.resolved == .zhHans ? "暂无任务历史。" : "No operation history yet.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(records) { record in
                        OperationHistoryRow(record: record)
                    }
                    HStack {
                        Spacer()
                        Button(language.resolved == .zhHans ? "清理已完成" : "Clear Finished") {
                            store.clearFinished(domains: domains)
                        }
                        .buttonStyle(.borderless)
                        .disabled(!records.contains { $0.status.isFinished })
                        .help(language.resolved == .zhHans ? "清理已完成任务记录" : "Clear finished operation records")
                    }
                }
            }
        }
    }
}

private struct OperationHistoryRow: View {
    @Environment(\.appLanguage) private var language
    var record: AppOperationRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 9) {
                Image(systemName: iconName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Text(record.target)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                StatusPill(title: record.status.title(language: language), systemImage: iconName, tint: tint)
                Text(record.durationText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 42, alignment: .trailing)
                copyMenu
            }

            Text(record.commandPreview)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .textSelection(.enabled)

            if !record.outputPreview.isEmpty {
                Text(record.outputPreview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
        }
        .padding(10)
        .background(CDTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }

    private var iconName: String {
        switch record.status {
        case .running:
            "hourglass"
        case .succeeded:
            "checkmark.circle"
        case .failed:
            "exclamationmark.triangle"
        }
    }

    private var tint: Color {
        switch record.status {
        case .running:
            CDTheme.dockerBlue
        case .succeeded:
            CDTheme.lime
        case .failed:
            CDTheme.ember
        }
    }

    private var copyMenu: some View {
        Menu {
            Button {
                copy(record.commandPreview)
            } label: {
                Label(language.resolved == .zhHans ? "复制命令" : "Copy command", systemImage: "terminal")
            }
            Button {
                copy(record.output.nilIfBlank ?? record.outputPreview)
            } label: {
                Label(language.resolved == .zhHans ? "复制输出" : "Copy output", systemImage: "doc.plaintext")
            }
            Button {
                copy(record.diagnosticReport(language: language))
            } label: {
                Label(language.resolved == .zhHans ? "复制诊断报告" : "Copy diagnostic report", systemImage: "stethoscope")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help(language.resolved == .zhHans ? "复制命令、输出或诊断报告" : "Copy command, output, or diagnostic report")
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}
