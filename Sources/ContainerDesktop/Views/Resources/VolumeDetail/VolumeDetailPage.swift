import SwiftUI

struct VolumeDetailPage: View {
    @Environment(\.appLanguage) private var language
    @Bindable var runtimeStore: RuntimeStore
    @Bindable var operationStore: AppOperationStore
    var name: String
    var initialTab: VolumeDetailTab = .overview
    @Binding var isPresented: Bool
    @Binding var resourceRoute: AppResourceRoute?

    @State private var detailStore: VolumeDetailStore
    @State private var browserStore = VolumeBrowserStore()

    init(
        runtimeStore: RuntimeStore,
        operationStore: AppOperationStore,
        name: String,
        initialTab: VolumeDetailTab = .overview,
        isPresented: Binding<Bool>,
        resourceRoute: Binding<AppResourceRoute?> = .constant(nil)
    ) {
        self.runtimeStore = runtimeStore
        self.operationStore = operationStore
        self.name = name
        self.initialTab = initialTab
        _isPresented = isPresented
        _resourceRoute = resourceRoute
        _detailStore = State(initialValue: VolumeDetailStore(
            volumeName: name,
            initialTab: initialTab,
            inspectLoader: { [runtimeStore] volumeName in
                try await runtimeStore.loadVolumeInspect(name: volumeName)
            }
        ))
    }

    private var resolvedVolume: VolumeSummary? {
        runtimeStore.volumes.first { $0.name == name }
    }

    var body: some View {
        Group {
            if let volume = resolvedVolume {
                SecondaryDetailPageContainer {
                    VStack(spacing: 12) {
                        VolumeDetailHeaderView(
                            volume: volume,
                            parentTitle: language.t(.volumes),
                            isRefreshing: runtimeStore.isRefreshing || detailStore.isLoadingInspect || browserStore.isLoading,
                            onBack: { closeDetail() },
                            onRefresh: { refresh(volume: volume) }
                        )

                        ResourceAssociationsPanel(
                            sections: VolumeResourceAssociations.make(
                                volume: volume,
                                operations: operationStore.records,
                                language: language
                            ).sections
                        ) { route in
                            resourceRoute = route
                        }

                        VolumeDetailTabBar(selection: $detailStore.selectedTab)

                        tabContent(volume: volume)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
                .task(id: volume.name) {
                    await detailStore.bootstrap()
                    await loadFilesIfNeeded(volume: volume)
                }
                .onChange(of: detailStore.selectedTab) { _, tab in
                    guard tab == .files else { return }
                    Task { await loadFilesIfNeeded(volume: volume) }
                }
            } else {
                ContentUnavailableView(
                    language.resolved == .zhHans ? "存储卷不可用" : "Volume unavailable",
                    systemImage: "externaldrive"
                )
                .task { closeDetail() }
            }
        }
    }

    @ViewBuilder
    private func tabContent(volume: VolumeSummary) -> some View {
        switch detailStore.selectedTab {
        case .overview:
            VolumeOverviewTabView(volume: volume)
        case .files:
            VolumeFilesTabView(
                runtimeStore: runtimeStore,
                volume: volume,
                browserStore: browserStore
            )
        case .metadata:
            VolumeMetadataTabView(volume: volume)
        case .inspect:
            VolumeInspectTabView(store: detailStore)
        }
    }

    private func refresh(volume: VolumeSummary) {
        Task {
            await runtimeStore.refreshAll()
            guard let refreshedVolume = runtimeStore.volumes.first(where: { $0.name == volume.name }) else {
                closeDetail()
                return
            }
            await detailStore.refreshInspect()
            if detailStore.selectedTab == .files {
                await browserStore.load(volume: refreshedVolume, relativePath: browserStore.snapshot?.relativePath ?? "")
            }
        }
    }

    private func loadFilesIfNeeded(volume: VolumeSummary) async {
        guard detailStore.selectedTab == .files, browserStore.snapshot == nil else { return }
        await browserStore.load(volume: volume)
    }

    private func closeDetail() {
        isPresented = false
    }
}
