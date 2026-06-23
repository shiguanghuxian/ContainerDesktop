import AppKit
import SwiftUI

struct ContainerLogsTabView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var store: ContainerDetailStore
    @State private var isLogViewAtBottom = true
    @State private var scrollToBottomRequestID = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            toolbar

            if let error = store.logsError {
                StatusBanner(text: error, systemImage: "exclamationmark.triangle", tint: CDTheme.ember)
            } else if store.isStreamingLogs {
                StatusBanner(text: language.resolved == .zhHans ? "正在跟随日志输出" : "Following log output", systemImage: "dot.radiowaves.left.and.right", tint: CDTheme.lime)
            }

            ReadOnlyMonospaceTextView(
                text: store.filteredLogsText.isEmpty ? "无输出。" : store.filteredLogsText,
                appearance: .console,
                autoScrollToBottom: shouldAutoFollowLogs,
                scrollToBottomRequestID: scrollToBottomRequestID,
                isScrolledToBottom: $isLogViewAtBottom,
                wrapsLines: false
            )
            .frame(height: 480)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(CDTheme.cyan.opacity(0.20))
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var shouldAutoFollowLogs: Bool {
        store.followLogs && !store.isLogsPaused && store.logsSearchText.trimmed.isEmpty
    }

    private var toolbar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                toggleControls
                Spacer(minLength: 8)
                searchField
                    .frame(minWidth: 180, idealWidth: 240, maxWidth: 280)
                actionButtons
            }

            VStack(alignment: .leading, spacing: 8) {
                toggleControls
                HStack(spacing: 8) {
                    searchField
                        .frame(maxWidth: .infinity)
                    actionButtons
                }
            }
        }
        .padding(10)
        .background(CDTheme.panelSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }

    private var toggleControls: some View {
        HStack(spacing: 10) {
            Toggle(language.resolved == .zhHans ? "Boot 日志" : "Boot logs", isOn: $store.bootLogs)
                .toggleStyle(.switch)
                .onChange(of: store.bootLogs) {
                    Task { await store.loadLogs() }
                }

            Toggle("Follow", isOn: Binding(
                get: { store.followLogs },
                set: { _ in Task { await store.toggleFollowLogs() } }
            ))
            .toggleStyle(.switch)

            Toggle(language.resolved == .zhHans ? "暂停" : "Pause", isOn: $store.isLogsPaused)
                .toggleStyle(.switch)
        }
        .fixedSize()
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(language.t(.search), text: $store.logsSearchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(CDTheme.inputSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            if !isLogViewAtBottom {
                Button {
                    scrollToBottomRequestID += 1
                } label: {
                    Image(systemName: "arrow.down.to.line")
                }
                .help(language.resolved == .zhHans ? "滚动到底部" : "Scroll to bottom")
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
        .fixedSize()
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}

struct StatusBanner: View {
    var text: String
    var systemImage: String
    var tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(text)
                .lineLimit(2)
            Spacer()
        }
        .font(.callout)
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .frame(minHeight: 34)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(tint.opacity(0.18))
        }
    }
}
