import SwiftUI

struct ContainerDetailPage: View {
    @Environment(\.appLanguage) private var language
    @Bindable var runtimeStore: RuntimeStore
    @Bindable var statsHistoryStore: ContainerStatsHistoryStore
    var containerID: String
    var parentTitle: String?
    @Binding var isPresented: Bool

    @State private var detailStore: ContainerDetailStore
    @State private var isConfirmingDelete = false

    init(
        runtimeStore: RuntimeStore,
        statsHistoryStore: ContainerStatsHistoryStore,
        containerID: String,
        parentTitle: String? = nil,
        isPresented: Binding<Bool>
    ) {
        self.runtimeStore = runtimeStore
        self.statsHistoryStore = statsHistoryStore
        self.containerID = containerID
        self.parentTitle = parentTitle
        _isPresented = isPresented
        _detailStore = State(initialValue: ContainerDetailStore(containerID: containerID))
    }

    private var resolvedContainer: ContainerSummary? {
        runtimeStore.containers.first(where: { $0.id == containerID })
    }

    var body: some View {
        Group {
            if let container = resolvedContainer {
                SecondaryDetailPageContainer {
                    VStack(spacing: 12) {
                        ContainerDetailHeaderView(
                            container: container,
                            inspectText: detailStore.inspectText,
                            parentTitle: parentTitle ?? language.t(.containers),
                            onBack: { isPresented = false },
                            onStartStop: { startStop(container) },
                            onRestart: { restart(container) },
                            onDelete: { isConfirmingDelete = true }
                        )

                        ContainerDetailTabBar(selection: $detailStore.selectedTab)

                        tabContent(container: container)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
                .task(id: container.id) {
                    await detailStore.bootstrap()
                }
                .onDisappear {
                    detailStore.stopAll()
                }
                .alert("删除容器？", isPresented: $isConfirmingDelete) {
                    Button(language.t(.delete), role: .destructive) {
                        delete(container)
                    }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("将删除容器 \(container.id)。运行中的容器需要先停止。")
                }
            } else {
                ContentUnavailableView(
                    language.resolved == .zhHans ? "容器不可用" : "Container unavailable",
                    systemImage: "shippingbox"
                )
                .task { isPresented = false }
            }
        }
    }

    @ViewBuilder
    private func tabContent(container: ContainerSummary) -> some View {
        switch detailStore.selectedTab {
        case .logs:
            ContainerLogsTabView(store: detailStore)
        case .inspect:
            ContainerInspectTabView(store: detailStore)
        case .exec:
            ContainerExecTabView(store: detailStore, container: container)
        case .files:
            ContainerFilesTabView(store: detailStore)
        case .stats:
            ContainerStatsTabView(statsHistoryStore: statsHistoryStore, container: container)
        }
    }

    private func startStop(_ container: ContainerSummary) {
        Task {
            if container.state == "running" {
                detailStore.stopTerminal()
                await runtimeStore.stopContainer(container.id)
            } else {
                await runtimeStore.startContainer(container.id)
            }
            await detailStore.refreshInspect()
        }
    }

    private func restart(_ container: ContainerSummary) {
        Task {
            detailStore.stopTerminal()
            await runtimeStore.restartContainer(container.id)
            await detailStore.refreshInspect()
        }
    }

    private func delete(_ container: ContainerSummary) {
        Task {
            detailStore.stopAll()
            await runtimeStore.deleteContainer(container.id)
            isPresented = false
        }
    }
}
