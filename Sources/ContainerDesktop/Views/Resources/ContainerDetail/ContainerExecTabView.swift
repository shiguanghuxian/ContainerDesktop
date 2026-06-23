import SwiftUI

struct ContainerExecTabView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var store: ContainerDetailStore
    var container: ContainerSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            toolbar

            if container.state != "running" {
                StatusBanner(
                    text: language.resolved == .zhHans ? "容器未运行。启动容器后才能进入 Exec 终端。" : "The container is not running. Start it before opening Exec.",
                    systemImage: "pause.circle",
                    tint: .secondary
                )
            }

            SwiftTermTerminalView(
                textSnapshot: store.terminalText,
                outputEvents: store.terminalOutputEvents,
                outputSequence: store.terminalOutputSequence,
                resetSequence: store.terminalResetSequence,
                isInputEnabled: isTerminalInputEnabled,
                onSizeChange: { columns, rows in
                    store.resizeTerminal(columns: columns, rows: rows)
                },
                onInput: { data in
                    store.sendTerminalInputData(data)
                }
            )
            .frame(minHeight: 460)
            .overlay(alignment: .bottomLeading) {
                if isTerminalInputEnabled {
                    Text(language.resolved == .zhHans ? "点击终端区域后可直接输入。默认 shell: sh" : "Click the terminal area and type. Default shell: sh")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.42))
                        .padding(10)
                }
            }
            .overlay {
                terminalLockOverlay
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .task {
            if container.state == "running", store.terminalState == .disconnected {
                await store.startTerminal()
            }
        }
    }

    private var toolbar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                terminalStatus
                Spacer(minLength: 8)
                toolbarActions
            }

            VStack(alignment: .leading, spacing: 8) {
                terminalStatus
                toolbarActions
            }
        }
        .padding(10)
        .background(CDTheme.panelSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }

    private var toolbarActions: some View {
        HStack(spacing: 8) {
            Menu {
                ExternalTerminalDestinationMenuItems { destination in
                    openExternalTerminal(destination: destination)
                }
            } label: {
                Label(language.resolved == .zhHans ? "打开外部终端" : "Open external terminal", systemImage: "macwindow")
            }
            .disabled(container.state != "running")
            .help(language.resolved == .zhHans ? "在外部终端打开 Exec" : "Open Exec in external terminal")

            Button {
                Task { await store.startTerminal() }
            } label: {
                Label(language.resolved == .zhHans ? "连接" : "Connect", systemImage: "terminal")
            }
            .buttonStyle(.borderedProminent)
            .disabled(container.state != "running" || store.terminalState.isConnected)
            .help(language.resolved == .zhHans ? "连接容器终端" : "Connect container terminal")

            Button {
                store.stopTerminal()
            } label: {
                Label(language.resolved == .zhHans ? "断开" : "Disconnect", systemImage: "xmark.circle")
            }
            .disabled(!store.terminalState.isConnected)
            .help(language.resolved == .zhHans ? "断开容器终端" : "Disconnect container terminal")

            Button {
                store.clearTerminal()
            } label: {
                Image(systemName: "eraser")
            }
            .help(language.resolved == .zhHans ? "清屏" : "Clear")
        }
        .fixedSize()
    }

    private var isTerminalInputEnabled: Bool {
        store.terminalState.isConnected && container.state == "running"
    }

    private var canConnect: Bool {
        container.state == "running" && store.terminalState != .connecting
    }

    @ViewBuilder
    private var terminalLockOverlay: some View {
        switch store.terminalState {
        case .disconnected:
            TerminalLockOverlay(
                title: language.resolved == .zhHans ? "终端已断开" : "Terminal disconnected",
                message: disconnectedMessage,
                connectTitle: language.resolved == .zhHans ? "连接" : "Connect",
                isConnectDisabled: !canConnect
            ) {
                Task { await store.startTerminal() }
            }
        case .failed(let message):
            TerminalLockOverlay(
                title: language.resolved == .zhHans ? "终端连接失败" : "Terminal connection failed",
                message: message,
                connectTitle: language.resolved == .zhHans ? "重新连接" : "Reconnect",
                isConnectDisabled: !canConnect
            ) {
                Task { await store.startTerminal() }
            }
        case .connecting, .connected:
            EmptyView()
        }
    }

    private var disconnectedMessage: String {
        if container.state != "running" {
            return language.resolved == .zhHans
                ? "容器未运行。启动容器后才能连接 Exec。"
                : "The container is not running. Start it before connecting Exec."
        }
        return language.resolved == .zhHans
            ? "已断开，点击连接重新开始。"
            : "Disconnected. Connect to start a new session."
    }

    @ViewBuilder
    private var terminalStatus: some View {
        switch store.terminalState {
        case .disconnected:
            StatusBanner(text: "Disconnected", systemImage: "circle", tint: .secondary)
                .frame(maxWidth: 220)
        case .connecting:
            StatusBanner(text: "Connecting", systemImage: "hourglass", tint: CDTheme.dockerBlue)
                .frame(maxWidth: 220)
        case .connected:
            StatusBanner(text: "Connected", systemImage: "checkmark.circle", tint: CDTheme.lime)
                .frame(maxWidth: 220)
        case .failed(let message):
            StatusBanner(text: message, systemImage: "exclamationmark.triangle", tint: CDTheme.ember)
                .frame(maxWidth: 420)
        }
    }

    private func openExternalTerminal(destination: ExternalTerminalDestination) {
        do {
            try ExternalTerminalLauncher.open(
                destination: destination,
                target: .container(id: container.id)
            )
        } catch {
            store.terminalState = .failed(error.localizedDescription)
        }
    }
}
