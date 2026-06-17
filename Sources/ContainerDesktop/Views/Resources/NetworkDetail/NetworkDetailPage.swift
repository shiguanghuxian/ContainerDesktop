import SwiftUI

struct NetworkDetailPage: View {
    @Environment(\.appLanguage) private var language
    @Bindable var runtimeStore: RuntimeStore
    var name: String
    @Binding var isPresented: Bool

    @State private var detailStore: NetworkDetailStore

    init(runtimeStore: RuntimeStore, name: String, isPresented: Binding<Bool>) {
        self.runtimeStore = runtimeStore
        self.name = name
        _isPresented = isPresented
        _detailStore = State(initialValue: NetworkDetailStore(
            networkName: name,
            inspectLoader: { [runtimeStore] networkName in
                try await runtimeStore.loadNetworkInspect(name: networkName)
            }
        ))
    }

    private var resolvedNetwork: NetworkSummary? {
        runtimeStore.networks.first { $0.name == name }
    }

    var body: some View {
        Group {
            if let network = resolvedNetwork {
                SecondaryDetailPageContainer {
                    VStack(spacing: 12) {
                        NetworkDetailHeaderView(
                            network: network,
                            parentTitle: language.t(.networks),
                            isRefreshing: runtimeStore.isRefreshing || detailStore.isLoadingInspect,
                            onBack: { closeDetail() },
                            onRefresh: { refresh(network: network) }
                        )

                        NetworkDetailTabBar(selection: $detailStore.selectedTab)

                        tabContent(network: network)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
                .task(id: network.name) {
                    await detailStore.bootstrap()
                }
            } else {
                ContentUnavailableView(
                    language.resolved == .zhHans ? "网络不可用" : "Network unavailable",
                    systemImage: "network"
                )
                .task { closeDetail() }
            }
        }
    }

    @ViewBuilder
    private func tabContent(network: NetworkSummary) -> some View {
        switch detailStore.selectedTab {
        case .overview:
            NetworkOverviewTabView(network: network)
        case .metadata:
            NetworkMetadataTabView(network: network)
        case .inspect:
            NetworkInspectTabView(store: detailStore)
        }
    }

    private func refresh(network: NetworkSummary) {
        Task {
            await runtimeStore.refreshAll()
            guard runtimeStore.networks.contains(where: { $0.name == network.name }) else {
                closeDetail()
                return
            }
            await detailStore.refreshInspect()
        }
    }

    private func closeDetail() {
        isPresented = false
    }
}
