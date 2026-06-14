import AppKit
import SwiftUI

struct MachineLogsTabView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var store: MachineDetailStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Toggle(language.resolved == .zhHans ? "Boot 日志" : "Boot logs", isOn: $store.bootLogs)
                    .toggleStyle(.switch)
                    .onChange(of: store.bootLogs) {
                        Task { await store.loadLogs() }
                    }

                Spacer()

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(language.t(.search), text: $store.logsSearchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 10)
                .frame(width: 260, height: 34)
                .background(CDTheme.inputSurface, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(CDTheme.separator)
                }

                Button {
                    copy(store.filteredLogsText)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .help(language.resolved == .zhHans ? "复制日志" : "Copy logs")

                Button {
                    store.clearLogs()
                } label: {
                    Image(systemName: "eraser")
                }
                .help(language.resolved == .zhHans ? "清空显示" : "Clear")

                Button {
                    Task { await store.loadLogs() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help(language.t(.refresh))
            }

            if let error = store.logsError {
                StatusBanner(text: error, systemImage: "exclamationmark.triangle", tint: CDTheme.ember)
            }

            TerminalBlock(text: store.filteredLogsText.isEmpty ? "无输出。" : store.filteredLogsText, minHeight: 460)
        }
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}
