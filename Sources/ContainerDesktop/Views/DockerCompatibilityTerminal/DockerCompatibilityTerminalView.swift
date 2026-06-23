import AppKit
import SwiftUI

struct DockerCompatibilityTerminalView: View {
    @Environment(\.appLanguage) private var language
    @AppStorage(DockerCompatibilityTerminalStyle.defaultsKey, store: .containerDesktopShared) private var styleRaw = DockerCompatibilityTerminalStyle.defaultStyle.rawValue
    @Bindable var store: DockerCompatibilityTerminalStore
    var onOpenStyleSettings: (() -> Void)?
    var onNewTab: (() -> Void)?
    var enforcesMinimumSize = true
    @State private var isControlsExpanded = false

    var body: some View {
        ZStack {
            terminalBackground
            terminal
        }
        .overlay(alignment: .topTrailing) {
            controlsOverlay
                .padding(10)
        }
        .frame(minWidth: enforcesMinimumSize ? 900 : nil, minHeight: enforcesMinimumSize ? 560 : nil)
        .background(terminalBackground)
        .task {
            if store.terminalState == .disconnected {
                await store.startTerminal()
            }
        }
    }

    private var terminalBackground: Color {
        terminalStyle.configuration.background.color
    }

    private var terminalStyle: DockerCompatibilityTerminalStyle {
        DockerCompatibilityTerminalStyle(rawValue: styleRaw) ?? .defaultStyle
    }

    private var controlsOverlay: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Button {
                withAnimation(.snappy(duration: 0.18)) {
                    isControlsExpanded.toggle()
                }
            } label: {
                Image(systemName: isControlsExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.86))
                    .frame(width: 30, height: 26)
                    .background(.black.opacity(0.48), in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.white.opacity(0.14))
                    }
            }
            .buttonStyle(.plain)
            .help(isControlsExpanded ? collapsedHelpText : expandedHelpText)

            if isControlsExpanded {
                controlsPanel
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var controlsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                IconTile(systemImage: "terminal", tint: CDTheme.dockerBlue, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(DockerCompatibilityTerminalStrings.routeDescription(language))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
            }

            statusBlock
            toolbarActions

            VStack(alignment: .leading, spacing: 6) {
                pathRow(
                    title: "shim",
                    text: store.shimPathText
                )
                pathRow(
                    title: "cwd",
                    text: store.workingDirectoryText
                )
            }
        }
        .padding(12)
        .frame(width: 520, alignment: .leading)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.white.opacity(0.14))
        }
        .shadow(color: .black.opacity(0.28), radius: 18, y: 10)
    }

    private var statusBlock: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                terminalStatus
                mappingStatus
            }

            VStack(alignment: .leading, spacing: 8) {
                terminalStatus
                mappingStatus
            }
        }
    }

    private var mappingStatus: some View {
        HStack(spacing: 6) {
            StatusPill(title: "docker", systemImage: "terminal", tint: CDTheme.dockerBlue)
            Image(systemName: "arrow.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.52))
            StatusPill(title: "container", systemImage: "shippingbox", tint: CDTheme.lime)
        }
    }

    private var toolbarActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                traceToggle
                styleSettingsButton
                iconButton(systemImage: "doc.on.doc", help: DockerCompatibilityTerminalStrings.copyShimPath(language)) {
                    copyShimPath()
                }
                iconButton(systemImage: "eraser", help: DockerCompatibilityTerminalStrings.clearTerminal(language)) {
                    store.clearTerminal()
                }
                iconButton(systemImage: "arrow.clockwise", help: DockerCompatibilityTerminalStrings.restartTerminal(language), isDisabled: store.terminalState == .connecting) {
                    Task { await store.restartTerminal() }
                }
                iconButton(systemImage: "xmark.circle", help: DockerCompatibilityTerminalStrings.disconnect(language), isDisabled: !store.terminalState.isConnected) {
                    store.stopTerminal()
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                traceToggle
                HStack(spacing: 8) {
                    styleSettingsButton
                    iconButton(systemImage: "doc.on.doc", help: DockerCompatibilityTerminalStrings.copyShimPath(language)) {
                        copyShimPath()
                    }
                    iconButton(systemImage: "eraser", help: DockerCompatibilityTerminalStrings.clearTerminal(language)) {
                        store.clearTerminal()
                    }
                    iconButton(systemImage: "arrow.clockwise", help: DockerCompatibilityTerminalStrings.restartTerminal(language), isDisabled: store.terminalState == .connecting) {
                        Task { await store.restartTerminal() }
                    }
                    iconButton(systemImage: "xmark.circle", help: DockerCompatibilityTerminalStrings.disconnect(language), isDisabled: !store.terminalState.isConnected) {
                        store.stopTerminal()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var styleSettingsButton: some View {
        if let onOpenStyleSettings {
            iconButton(systemImage: "gearshape", help: DockerCompatibilityTerminalStrings.terminalSettings(language)) {
                onOpenStyleSettings()
            }
        }
    }

    private var traceToggle: some View {
        Button {
            guard !store.terminalState.isConnected, store.terminalState != .connecting else { return }
            store.verboseConversions.toggle()
        } label: {
            Label(DockerCompatibilityTerminalStrings.traceTitle(language), systemImage: "text.bubble")
                .font(.caption.weight(.semibold))
                .foregroundStyle(store.verboseConversions ? CDTheme.lime : .white.opacity(0.82))
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(actionButtonBackground(isActive: store.verboseConversions), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(actionButtonBorder(isActive: store.verboseConversions))
                }
        }
        .buttonStyle(.plain)
        .disabled(store.terminalState.isConnected || store.terminalState == .connecting)
        .opacity(store.terminalState.isConnected || store.terminalState == .connecting ? 0.55 : 1)
        .help(DockerCompatibilityTerminalStrings.traceHelp(language))
    }

    private func iconButton(
        systemImage: String,
        help: String,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.86))
                .frame(width: 26, height: 24)
                .background(actionButtonBackground(), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(actionButtonBorder())
                }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.48 : 1)
        .help(help)
    }

    private func actionButtonBackground(isActive: Bool = false) -> Color {
        isActive ? CDTheme.lime.opacity(0.18) : .white.opacity(0.10)
    }

    private func actionButtonBorder(isActive: Bool = false) -> Color {
        isActive ? CDTheme.lime.opacity(0.32) : .white.opacity(0.14)
    }

    private func pathRow(title: String, text: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption2.monospaced().weight(.semibold))
                .foregroundStyle(.white.opacity(0.42))
                .frame(width: 32, alignment: .leading)
            Text(text)
                .font(.caption.monospaced())
                .foregroundStyle(.white.opacity(0.56))
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.white.opacity(0.10))
        }
    }

    private var terminal: some View {
        SwiftTermTerminalView(
            textSnapshot: store.terminalText,
            outputEvents: store.terminalOutputEvents,
            outputSequence: store.terminalOutputSequence,
            resetSequence: store.terminalResetSequence,
            isInputEnabled: store.terminalState.isConnected,
            style: terminalStyle.configuration,
            language: language,
            contextMenuActions: terminalContextMenuActions,
            onSizeChange: { columns, rows in
                store.resizeTerminal(columns: columns, rows: rows)
            },
            onCurrentDirectoryChange: { directory in
                store.updateCurrentDirectory(fromTerminalDirectory: directory)
            },
            onInput: { data in
                store.sendTerminalInputData(data)
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .overlay {
            terminalLockOverlay
        }
    }

    @ViewBuilder
    private var terminalStatus: some View {
        switch store.terminalState {
        case .disconnected:
            StatusPill(title: DockerCompatibilityTerminalStrings.disconnectedStatus(language), systemImage: "circle", tint: .secondary)
        case .connecting:
            StatusPill(title: DockerCompatibilityTerminalStrings.connectingStatus(language), systemImage: "hourglass", tint: CDTheme.dockerBlue)
        case .connected:
            StatusPill(title: DockerCompatibilityTerminalStrings.connectedStatus(language), systemImage: "checkmark.circle", tint: CDTheme.lime)
        case .failed:
            StatusPill(title: DockerCompatibilityTerminalStrings.failedStatus(language), systemImage: "exclamationmark.triangle", tint: CDTheme.ember)
        }
    }

    @ViewBuilder
    private var terminalLockOverlay: some View {
        switch store.terminalState {
        case .disconnected:
            TerminalLockOverlay(
                title: DockerCompatibilityTerminalStrings.disconnectedTitle(language),
                message: DockerCompatibilityTerminalStrings.disconnectedMessage(language),
                connectTitle: DockerCompatibilityTerminalStrings.connect(language)
            ) {
                Task { await store.startTerminal() }
            }
        case .failed(let message):
            TerminalLockOverlay(
                title: DockerCompatibilityTerminalStrings.failedTitle(language),
                message: message,
                connectTitle: DockerCompatibilityTerminalStrings.reconnect(language)
            ) {
                Task { await store.restartTerminal() }
            }
        case .connecting, .connected:
            EmptyView()
        }
    }

    private var title: String {
        DockerCompatibilityTerminalStrings.windowTitle(language)
    }

    private var expandedHelpText: String {
        DockerCompatibilityTerminalStrings.expandControls(language)
    }

    private var collapsedHelpText: String {
        DockerCompatibilityTerminalStrings.collapseControls(language)
    }

    private var terminalContextMenuActions: [TerminalContextMenuAction] {
        guard let onNewTab else { return [] }
        return [
            TerminalContextMenuAction(title: DockerCompatibilityTerminalStrings.newTab(language)) {
                onNewTab()
            },
        ]
    }

    private func copyShimPath() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(store.shimPathText, forType: .string)
    }
}
