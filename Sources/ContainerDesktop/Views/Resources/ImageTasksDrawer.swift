import SwiftUI

struct ImageTasksDrawer: View {
    @Environment(\.appLanguage) private var language
    var operationStore: AppOperationStore
    var statusMessage: String?
    var statusIsError: Bool
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            DrawerHeader(
                title: language.resolved == .zhHans ? "镜像任务" : "Image Tasks",
                subtitle: language.resolved == .zhHans ? "最近镜像操作和状态输出" : "Recent image operations and status output",
                systemImage: "clock.arrow.circlepath",
                onClose: onClose
            )

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let statusMessage {
                        StatusBanner(
                            text: statusMessage,
                            systemImage: statusIsError ? "exclamationmark.triangle" : "checkmark.circle",
                            tint: statusIsError ? CDTheme.ember : CDTheme.lime
                        )
                    }

                    OperationHistoryPanel(
                        store: operationStore,
                        domains: [.image],
                        title: language.resolved == .zhHans ? "镜像任务" : "Image Tasks",
                        limit: 20
                    )
                }
                .padding(16)
            }
            .thinScrollBars()
        }
        .drawerSurface(width: 620)
    }
}
