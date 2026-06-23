import SwiftUI

struct ContainerDetailPage: View {
    @Environment(\.appLanguage) private var language
    @Bindable var runtimeStore: RuntimeStore
    @Bindable var composeStore: ComposeProjectStore
    @Bindable var operationStore: AppOperationStore
    @Bindable var statsHistoryStore: ContainerStatsHistoryStore
    var containerID: String
    var initialTab: ContainerDetailTab?
    var parentTitle: String?
    @Binding var isPresented: Bool
    @Binding var resourceRoute: AppResourceRoute?

    @State private var detailStore: ContainerDetailStore
    @State private var isConfirmingDelete = false

    init(
        runtimeStore: RuntimeStore,
        composeStore: ComposeProjectStore,
        operationStore: AppOperationStore,
        statsHistoryStore: ContainerStatsHistoryStore,
        containerID: String,
        initialTab: ContainerDetailTab? = nil,
        parentTitle: String? = nil,
        isPresented: Binding<Bool>,
        resourceRoute: Binding<AppResourceRoute?> = .constant(nil)
    ) {
        self.runtimeStore = runtimeStore
        self.composeStore = composeStore
        self.operationStore = operationStore
        self.statsHistoryStore = statsHistoryStore
        self.containerID = containerID
        self.initialTab = initialTab
        self.parentTitle = parentTitle
        _isPresented = isPresented
        _resourceRoute = resourceRoute
        let store = ContainerDetailStore(containerID: containerID)
        if let initialTab {
            store.selectedTab = initialTab
        }
        _detailStore = State(initialValue: store)
    }

    private var resolvedContainer: ContainerSummary? {
        runtimeStore.containers.first(where: { $0.id == containerID })
    }

    var body: some View {
        Group {
            if let container = resolvedContainer {
                SecondaryDetailPageContainer {
                    VStack(spacing: 12) {
                        fixedTopContent(container: container)

                        tabContent(container: container)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
                .task(id: container.id) {
                    if let initialTab {
                        detailStore.selectedTab = initialTab
                    }
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

    private func fixedTopContent(container: ContainerSummary) -> some View {
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

            ResourceAssociationsPanel(sections: associations(for: container).sections) { route in
                resourceRoute = route
            }

            ContainerDetailTabBar(selection: $detailStore.selectedTab)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
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

    private func associations(for container: ContainerSummary) -> ContainerResourceAssociations {
        ContainerResourceAssociations.make(
            container: container,
            inspectText: detailStore.inspectText,
            images: runtimeStore.images,
            volumes: runtimeStore.volumes,
            networks: runtimeStore.networks,
            composeProjects: composeStore.projects,
            browserPortTargets: runtimeStore.browserPortTargets(for: container),
            operations: operationStore.records,
            language: language
        )
    }
}
