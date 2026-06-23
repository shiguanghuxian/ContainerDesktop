import SwiftUI

struct ImageDetailPage: View {
    @Environment(\.appLanguage) private var language
    @Bindable var runtimeStore: RuntimeStore
    @Bindable var operationStore: AppOperationStore
    var reference: String
    @Binding var isPresented: Bool
    @Binding var showTasksDrawer: Bool
    @Binding var resourceRoute: AppResourceRoute?

    @State private var detailStore: ImageDetailStore

    init(
        runtimeStore: RuntimeStore,
        operationStore: AppOperationStore,
        reference: String,
        isPresented: Binding<Bool>,
        showTasksDrawer: Binding<Bool>,
        resourceRoute: Binding<AppResourceRoute?> = .constant(nil)
    ) {
        self.runtimeStore = runtimeStore
        self.operationStore = operationStore
        self.reference = reference
        _isPresented = isPresented
        _showTasksDrawer = showTasksDrawer
        _resourceRoute = resourceRoute
        _detailStore = State(initialValue: ImageDetailStore(reference: reference))
    }

    private var resolvedImage: ImageSummary? {
        runtimeStore.images.first(where: { $0.reference == reference })
    }

    var body: some View {
        Group {
            if let image = resolvedImage {
                SecondaryDetailPageContainer {
                    VStack(spacing: 12) {
                        ImageDetailHeaderView(
                            image: image,
                            selectedVariant: detailStore.selectedVariant(in: image),
                            parentTitle: language.t(.images),
                            isRefreshing: runtimeStore.isRefreshing,
                            onBack: { closeDetail() },
                            onRefresh: { refresh(image: image) },
                            onOpenTasks: { showTasksDrawer = true }
                        )

                        ResourceAssociationsPanel(
                            sections: ImageResourceAssociations.make(
                                image: image,
                                containers: runtimeStore.containers,
                                operations: operationStore.records,
                                language: language
                            ).sections
                        ) { route in
                            resourceRoute = route
                        }

                        ImageDetailTabBar(selection: $detailStore.selectedTab)

                        tabContent(image: image)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
                .task(id: image.reference) {
                    await detailStore.bootstrap(image: image)
                }
                .sheet(isPresented: $showTasksDrawer) {
                    ImageTasksDrawer(
                        operationStore: operationStore,
                        statusMessage: runtimeStore.imageOperationStatusMessage,
                        statusIsError: runtimeStore.imageOperationStatusIsError,
                        onClose: { showTasksDrawer = false }
                    )
                }
            } else {
                ContentUnavailableView(
                    language.resolved == .zhHans ? "镜像不可用" : "Image unavailable",
                    systemImage: "photo.stack"
                )
                .task { closeDetail() }
            }
        }
    }

    @ViewBuilder
    private func tabContent(image: ImageSummary) -> some View {
        switch detailStore.selectedTab {
        case .overview:
            ImageOverviewTabView(store: detailStore, image: image)
        case .layers:
            ImageLayersTabView(store: detailStore, image: image)
        case .inspect:
            ImageInspectTabView(store: detailStore)
        }
    }

    private func refresh(image: ImageSummary) {
        Task {
            await runtimeStore.refreshAll()
            detailStore.selectInitialVariant(from: image)
            await detailStore.refreshInspect()
        }
    }

    private func closeDetail() {
        isPresented = false
    }
}
