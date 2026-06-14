import AppKit
import SwiftUI

struct MachineRunTabView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var store: MachineDetailStore
    var machine: MachineSummary
    var onCommandFinished: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                StatusBanner(
                    text: machine.isRunning ? "Ready" : (language.resolved == .zhHans ? "执行命令会自动启动 Machine" : "Running a command boots the Machine"),
                    systemImage: machine.isRunning ? "checkmark.circle" : "play.circle",
                    tint: machine.isRunning ? CDTheme.lime : CDTheme.dockerBlue
                )
                .frame(maxWidth: 320)

                Spacer()

                Button {
                    copy(store.commandOutput)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .disabled(store.commandOutput.isEmpty)
                .help(language.resolved == .zhHans ? "复制输出" : "Copy output")

                Button {
                    store.clearCommandOutput()
                } label: {
                    Image(systemName: "eraser")
                }
                .help(language.resolved == .zhHans ? "清空输出" : "Clear")
            }

            HStack(spacing: 10) {
                TextField("uname -a", text: $store.commandText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        runCommand()
                    }

                Button {
                    runCommand()
                } label: {
                    Label(language.resolved == .zhHans ? "运行" : "Run", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isCommandRunning)
            }

            if let error = store.commandError {
                StatusBanner(text: error, systemImage: "exclamationmark.triangle", tint: CDTheme.ember)
            }

            TerminalBlock(
                text: store.commandOutput.isEmpty ? "—" : store.commandOutput,
                minHeight: 460
            )
        }
    }

    private func runCommand() {
        Task {
            await store.runCommand()
            await onCommandFinished()
        }
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}
