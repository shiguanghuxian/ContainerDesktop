import SwiftUI

struct DockerCompatibilityTerminalTabsView: View {
    @Environment(\.appLanguage) private var language
    @AppStorage(DockerCompatibilityTerminalStyle.defaultsKey, store: .containerDesktopShared) private var styleRaw = DockerCompatibilityTerminalStyle.defaultStyle.rawValue
    @Bindable var tabsStore: DockerCompatibilityTerminalTabsStore
    var onOpenStyleSettings: (() -> Void)?
    var onCloseWindow: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            if tabsStore.tabs.count > 1 {
                tabBar
            }

            if let selectedTab = tabsStore.selectedTab {
                DockerCompatibilityTerminalView(
                    store: selectedTab.store,
                    onOpenStyleSettings: onOpenStyleSettings,
                    onNewTab: {
                        tabsStore.newTab()
                    },
                    enforcesMinimumSize: false
                )
                .id(selectedTab.id)
            }
        }
        .frame(minWidth: 900, minHeight: 560)
        .background(terminalBackground)
    }

    private var terminalStyle: DockerCompatibilityTerminalStyle {
        DockerCompatibilityTerminalStyle(rawValue: styleRaw) ?? .defaultStyle
    }

    private var terminalBackground: Color {
        terminalStyle.configuration.background.color
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(tabsStore.tabs) { tab in
                        tabItem(tab)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
            }

            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(width: 1)
                .padding(.vertical, 6)

            Button {
                tabsStore.newTab()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 30, height: 26)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.84))
            .help(DockerCompatibilityTerminalStrings.newTab(language))
            .padding(.horizontal, 6)
        }
        .frame(height: 36)
        .background(.black.opacity(0.76))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(height: 1)
        }
    }

    private func tabItem(_ tab: DockerCompatibilityTerminalTab) -> some View {
        let isSelected = tab.id == tabsStore.selectedTab?.id
        return HStack(spacing: 3) {
            Button {
                tabsStore.selectTab(id: tab.id)
            } label: {
                HStack(spacing: 7) {
                    Circle()
                        .fill(statusColor(for: tab.store.terminalState))
                        .frame(width: 7, height: 7)
                    Text(tab.title)
                        .font(.caption.weight(isSelected ? .semibold : .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 160, alignment: .leading)
                }
                .padding(.leading, 9)
                .padding(.trailing, 4)
                .frame(height: 26)
            }
            .buttonStyle(.plain)

            Button {
                closeTab(tab.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(isSelected ? 0.72 : 0.48))
            .help(DockerCompatibilityTerminalStrings.closeTab(language))
            .padding(.trailing, 5)
        }
        .foregroundStyle(.white.opacity(isSelected ? 0.92 : 0.66))
        .background(tabBackground(isSelected: isSelected), in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(.white.opacity(isSelected ? 0.18 : 0.08))
        }
    }

    private func tabBackground(isSelected: Bool) -> Color {
        isSelected ? .white.opacity(0.14) : .white.opacity(0.06)
    }

    private func statusColor(for state: TerminalSessionState) -> Color {
        switch state {
        case .connected:
            return CDTheme.lime
        case .connecting:
            return CDTheme.dockerBlue
        case .failed:
            return CDTheme.ember
        case .disconnected:
            return .secondary
        }
    }

    private func closeTab(_ id: UUID) {
        if tabsStore.closeTab(id: id) == .closedLastTab {
            onCloseWindow?()
        }
    }
}
