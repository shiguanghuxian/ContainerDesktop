import SwiftUI

struct DockerCompatibilityTerminalTabsView: View {
    @Environment(\.appLanguage) private var language
    @AppStorage(DockerCompatibilityTerminalStyle.defaultsKey, store: .containerDesktopShared) private var styleRaw = DockerCompatibilityTerminalStyle.defaultStyle.rawValue
    @Bindable var tabsStore: DockerCompatibilityTerminalTabsStore
    var onOpenStyleSettings: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            topChrome

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

    private var palette: DockerCompatibilityTerminalChromePalette {
        DockerCompatibilityTerminalWindowChrome.palette(for: terminalStyle)
    }

    @ViewBuilder
    private var topChrome: some View {
        if tabsStore.tabs.count > 1 {
            tabBar
        } else {
            singleTabDragBar
        }
    }

    private var singleTabDragBar: some View {
        HStack(spacing: 10) {
            Spacer()
                .frame(width: DockerCompatibilityTerminalWindowChrome.trafficLightReservedWidth)

            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor(for: tabsStore.selectedTab?.store.terminalState ?? .disconnected))
                    .frame(width: 7, height: 7)
                Text(DockerCompatibilityTerminalStrings.windowTitle(language))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.foreground)
                    .lineLimit(1)
                if let selectedTab = tabsStore.selectedTab {
                    Text(selectedTab.title)
                        .font(.caption.monospaced())
                        .foregroundStyle(palette.subduedForeground)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            dragRegion

            addTabButton
                .padding(.trailing, 8)
        }
        .frame(height: 34)
        .background(palette.background)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.separator)
                .frame(height: 1)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            Spacer()
                .frame(width: DockerCompatibilityTerminalWindowChrome.trafficLightReservedWidth)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(tabsStore.tabs) { tab in
                        tabItem(tab)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
            }

            dragRegion
                .frame(width: 28)

            Rectangle()
                .fill(palette.separator)
                .frame(width: 1)
                .padding(.vertical, 6)

            addTabButton
            .padding(.horizontal, 6)
        }
        .frame(height: 38)
        .background(palette.background)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.separator)
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
                        .frame(minWidth: 74, maxWidth: 170, alignment: .leading)
                }
                .padding(.leading, 9)
                .padding(.trailing, 4)
                .frame(height: 27)
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
            .foregroundStyle(isSelected ? palette.subduedForeground : palette.mutedForeground)
            .help(DockerCompatibilityTerminalStrings.closeTab(language))
            .padding(.trailing, 5)
        }
        .foregroundStyle(isSelected ? palette.foreground : palette.subduedForeground)
        .background(tabBackground(isSelected: isSelected), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isSelected ? palette.selectedTabBorder : palette.separator)
        }
    }

    private func tabBackground(isSelected: Bool) -> Color {
        isSelected ? palette.selectedTabBackground : palette.inactiveTabBackground
    }

    private var addTabButton: some View {
        Button {
            tabsStore.newTab()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 30, height: 26)
                .background(palette.controlBackground, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .foregroundStyle(palette.foreground)
        .help(DockerCompatibilityTerminalStrings.newTab(language))
    }

    private var dragRegion: some View {
        WindowDragZoomRegion()
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
        tabsStore.closeTab(id: id)
    }
}
