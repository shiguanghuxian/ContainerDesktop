import SwiftUI

struct OperationHistoryPanel: View {
    @Environment(\.appLanguage) private var language
    var store: AppOperationStore
    var domains: Set<AppOperationDomain>
    var title: String
    var limit = 5

    private var records: [AppOperationRecord] {
        store.recent(domains: domains, limit: limit)
    }

    var body: some View {
        PanelView(title: title, subtitle: language.resolved == .zhHans ? "最近操作与输出摘要" : "Recent operations and output", systemImage: "clock.arrow.circlepath") {
            VStack(alignment: .leading, spacing: 10) {
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
}
