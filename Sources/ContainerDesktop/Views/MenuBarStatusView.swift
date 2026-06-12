import AppKit
import SwiftUI

struct MenuBarStatusView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.openWindow) private var openWindow
    @Bindable var runtimeStore: RuntimeStore
    @Bindable var composeStore: ComposeProjectStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(runtimeStore.statusTitle(language: language))
                .font(.headline)

            Button(language.resolved == .zhHans ? "打开主窗口" : "Open Main Window") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }

            Divider()

            Button(runtimeStore.environment.systemRunning ? language.t(.stopSystem) : language.t(.startSystem)) {
                Task {
                    if runtimeStore.environment.systemRunning {
                        await runtimeStore.stopSystem()
                    } else {
                        await runtimeStore.startSystem()
                    }
                }
            }

            Button(language.resolved == .zhHans ? "刷新资源" : "Refresh Resources") {
                Task { await runtimeStore.refreshAll() }
            }

            if let recent = composeStore.projects.first {
                Button(language.t(.recentCompose)) {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Text(recent.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Divider()

            Button(language.resolved == .zhHans ? "退出" : "Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 260)
        .task {
            await runtimeStore.bootstrap()
            await composeStore.load()
        }
    }
}
