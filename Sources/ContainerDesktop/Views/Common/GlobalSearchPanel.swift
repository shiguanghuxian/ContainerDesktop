import SwiftUI

struct GlobalSearchPanel: View {
    @Environment(\.appLanguage) private var language
    var query: String
    var actions: [AppQuickAction]
    @Binding var selectedID: AppQuickAction.ID?
    var onSelect: (AppQuickAction) -> Void

    private var groupedActions: [(AppQuickActionGroup, [AppQuickAction])] {
        AppQuickActionGroup.allCases.compactMap { group in
            let groupActions = actions.filter { $0.group == group }
            guard !groupActions.isEmpty else { return nil }
            return (group, groupActions)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if actions.isEmpty {
                Text(language.resolved == .zhHans ? "没有匹配：\(query)" : "No matches: \(query)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(groupedActions, id: \.0) { group, groupActions in
                            section(group: group, actions: groupActions)
                        }
                    }
                    .padding(.trailing, 2)
                }
                .thinScrollBars()
                .frame(maxHeight: 520)
            }
        }
        .padding(10)
        .frame(width: 420)
        .background(CDTheme.panelSurface, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(CDTheme.separator)
        }
        .shadow(color: CDTheme.panelShadow, radius: 18, x: 0, y: 10)
        .onAppear {
            ensureSelection()
        }
        .onChange(of: actions.map(\.id)) { _, _ in
            ensureSelection()
        }
    }

    private var header: some View {
        HStack {
            Text(language.resolved == .zhHans ? "Command Palette" : "Command Palette")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Spacer()
            HStack(spacing: 6) {
                Text("↑↓")
                Text("Return")
            }
            .font(.caption2.monospaced())
            .foregroundStyle(.secondary)
        }
    }

    private func section(group: AppQuickActionGroup, actions: [AppQuickAction]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(group.title(language: language))
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(actions) { action in
                QuickActionRow(
                    action: action,
                    isSelected: action.id == selectedID,
                    onSelect: { onSelect(action) },
                    onHover: {
                        selectedID = action.id
                    }
                )
            }
        }
    }

    private func ensureSelection() {
        guard !actions.isEmpty else {
            selectedID = nil
            return
        }
        if let selectedID, actions.contains(where: { $0.id == selectedID }) {
            return
        }
        selectedID = actions.first?.id
    }
}

private struct QuickActionRow: View {
    @Environment(\.appLanguage) private var language
    var action: AppQuickAction
    var isSelected: Bool
    var onSelect: () -> Void
    var onHover: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: action.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(action.title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(action.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 8)

                Text(kindTitle)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 6)
                    .frame(height: 20)
                    .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 5))
            }
            .padding(.horizontal, 10)
            .frame(height: 46)
            .background(rowBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? tint.opacity(0.34) : CDTheme.separator.opacity(0.72))
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { onHover() }
        }
        .help(action.subtitle)
    }

    private var rowBackground: Color {
        isSelected ? CDTheme.selectionSurface : CDTheme.inputSurface
    }

    private var tint: Color {
        switch action.kind {
        case .navigate: CDTheme.dockerBlue
        case .execute: CDTheme.lime
        case .copyText: CDTheme.violet
        case .openURL: CDTheme.cyan
        case .confirmDestructive: CDTheme.ember
        }
    }

    private var kindTitle: String {
        switch action.kind {
        case .navigate:
            language.resolved == .zhHans ? "打开" : "Open"
        case .execute:
            language.resolved == .zhHans ? "执行" : "Run"
        case .copyText:
            language.resolved == .zhHans ? "复制" : "Copy"
        case .openURL:
            "URL"
        case .confirmDestructive:
            language.resolved == .zhHans ? "确认" : "Confirm"
        }
    }
}
