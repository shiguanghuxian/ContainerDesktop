import SwiftUI

struct MachineExecTabView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var store: MachineDetailStore
    var machine: MachineSummary
    var onConnectionChanged: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            toolbar

            if !machine.isRunning {
                StatusBanner(
                    text: language.resolved == .zhHans ? "Machine 未运行。点击连接会自动启动 Machine。" : "The machine is not running. Connecting will boot it automatically.",
                    systemImage: "play.circle",
                    tint: CDTheme.dockerBlue
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
        .task(id: machine.id) {
            if machine.isRunning, store.terminalState == .disconnected {
                await connect()
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
            Button {
                openExternalTerminal()
            } label: {
                Label(language.resolved == .zhHans ? "外部终端" : "External Terminal", systemImage: "macwindow")
            }
            .help(language.resolved == .zhHans ? "在外部终端打开 Machine" : "Open Machine in external terminal")

            Button {
                Task { await connect() }
            } label: {
                Label(language.resolved == .zhHans ? "连接" : "Connect", systemImage: "terminal")
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.terminalState.isConnected || store.terminalState == .connecting)
            .help(language.resolved == .zhHans ? "连接 Machine 终端" : "Connect Machine terminal")

            Button {
                disconnect()
            } label: {
                Label(language.resolved == .zhHans ? "断开" : "Disconnect", systemImage: "xmark.circle")
            }
            .disabled(!store.terminalState.isConnected)
            .help(language.resolved == .zhHans ? "断开 Machine 终端" : "Disconnect Machine terminal")

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
        store.terminalState.isConnected
    }

    private var canConnect: Bool {
        !store.terminalState.isConnected && store.terminalState != .connecting
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
                Task { await connect() }
            }
        case .failed(let message):
            TerminalLockOverlay(
                title: language.resolved == .zhHans ? "终端连接失败" : "Terminal connection failed",
                message: message,
                connectTitle: language.resolved == .zhHans ? "重新连接" : "Reconnect",
                isConnectDisabled: !canConnect
            ) {
                Task { await connect() }
            }
        case .connecting, .connected:
            EmptyView()
        }
    }

    private var disconnectedMessage: String {
        if !machine.isRunning {
            return language.resolved == .zhHans
                ? "已断开，点击连接会自动启动 Machine 并重新开始。"
                : "Disconnected. Connect to boot the machine and start a new session."
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

    private func connect() async {
        await store.startTerminal()
        await onConnectionChanged()
    }

    private func disconnect() {
        store.stopTerminal()
        Task {
            await onConnectionChanged()
        }
    }

    private func openExternalTerminal() {
        do {
            try SystemTerminalLauncher.openMachineShell(id: machine.id)
        } catch {
            store.terminalState = .failed(error.localizedDescription)
        }
    }
}
