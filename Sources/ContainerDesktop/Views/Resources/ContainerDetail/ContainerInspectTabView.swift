import AppKit
import SwiftUI

struct ContainerInspectTabView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var store: ContainerDetailStore

    private var visibleText: String {
        let source = store.inspectText
        let query = store.inspectSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return source }
        return source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { $0.localizedCaseInsensitiveContains(query) }
            .joined(separator: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            toolbar

            if let error = store.inspectError {
                StatusBanner(text: error, systemImage: "exclamationmark.triangle", tint: CDTheme.ember)
            }

            ReadOnlyMonospaceTextView(
                text: visibleText,
                appearance: .code,
                autoScrollToBottom: false,
                wrapsLines: false
            )
            .frame(minHeight: 520)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(CDTheme.separator)
            }
        }
    }

    private var toolbar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                titleLabel
                searchField
                    .frame(minWidth: 180, idealWidth: 260, maxWidth: 320)
                Spacer(minLength: 8)
                actionButtons
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    titleLabel
                    Spacer(minLength: 8)
                    actionButtons
                }
                searchField
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(10)
        .background(CDTheme.panelSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }

    private var titleLabel: some View {
        Label("Raw JSON", systemImage: "curlybraces")
            .font(.callout.weight(.semibold))
            .foregroundStyle(CDTheme.dockerBlue)
            .fixedSize()
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(language.t(.search), text: $store.inspectSearchText)
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
            Button {
                copy(visibleText)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .help(language.resolved == .zhHans ? "复制 JSON" : "Copy JSON")

            Button {
                Task { await store.refreshInspect() }
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
