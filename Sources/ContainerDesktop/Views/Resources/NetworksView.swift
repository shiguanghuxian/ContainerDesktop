import SwiftUI

struct NetworksView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var runtimeStore: RuntimeStore
    @Binding var resourceRoute: AppResourceRoute?
    @State private var searchText = ""
    @State private var newNetworkName = ""
    @State private var subnet = ""
    @State private var subnetV6 = ""
    @State private var internalOnly = false
    @State private var plugin = ""
    @State private var labels = ""
    @State private var options = ""
    @State private var showAdvancedCreateOptions = false
    @State private var showCreatePopover = false
    @State private var detailName: String?
    @State private var detailInitialTab: NetworkDetailTab = .overview
    @State private var selectedName: String?
    @State private var pendingDelete: NetworkSummary?
    @State private var drawerMode: DetailDrawerMode = .overview

    init(
        runtimeStore: RuntimeStore,
        resourceRoute: Binding<AppResourceRoute?> = .constant(nil)
    ) {
        self.runtimeStore = runtimeStore
        _resourceRoute = resourceRoute
    }

    private var filteredNetworks: [NetworkSummary] {
        let query = searchText.trimmed.lowercased()
        guard !query.isEmpty else { return runtimeStore.networks }
        return runtimeStore.networks.filter {
            $0.name.lowercased().contains(query)
                || $0.ipv4ConfigurationText.lowercased().contains(query)
                || $0.ipv6ConfigurationText.lowercased().contains(query)
        }
    }

    private var selectedNetwork: NetworkSummary? {
        guard let selectedName else { return nil }
        return runtimeStore.networks.first { $0.name == selectedName }
    }

    private var isDetailPresented: Binding<Bool> {
        Binding(
            get: { detailName != nil },
            set: { if !$0 { detailName = nil } }
        )
    }

    var body: some View {
        Group {
            if let detailName {
                NetworkDetailPage(
                    runtimeStore: runtimeStore,
                    name: detailName,
                    initialTab: detailInitialTab,
                    isPresented: isDetailPresented
                )
            } else {
                DrawerPageLayout(isDrawerPresented: selectedNetwork != nil, onDismiss: {
                    selectedName = nil
                }) {
                    pageContent
                } drawer: {
                    if let selectedNetwork {
                        DetailDrawer(
                            mode: $drawerMode,
                            title: selectedNetwork.name,
                            subtitle: "container network inspect",
                            systemImage: "network",
                            rawText: runtimeStore.selectedInspectorText,
                            onClose: {
                                selectedName = nil
                            }
                        ) {
                            VStack(alignment: .leading, spacing: 16) {
                                NetworkOverviewTabView(network: selectedNetwork)
                                NetworkMetadataTabView(network: selectedNetwork)
                            }
                        }
                    }
                }
            }
        }
        .alert("删除网络？", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            if let network = pendingDelete {
                Button(language.t(.delete), role: .destructive) {
                    pendingDelete = nil
                    Task { await runtimeStore.deleteNetwork(network.name) }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将删除网络 \(pendingDelete?.name ?? "所选网络")。系统或正在使用的网络可能无法删除。")
        }
        .onAppear {
            consumeResourceRoute()
        }
        .onChange(of: resourceRoute) { _, route in
            consumeResourceRoute(route)
        }
    }

    private func consumeResourceRoute(_ route: AppResourceRoute? = nil) {
        let route = route ?? resourceRoute
        guard case .network(let name, let tab) = route else { return }
        selectedName = nil
        detailInitialTab = tab ?? .overview
        detailName = name
        resourceRoute = nil
    }

    private var pageContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(
                title: language.t(.networks),
                subtitle: language.t(.networksSubtitle),
                systemImage: "network"
            ) {
                Button {
                    showCreatePopover = true
                } label: {
                    if runtimeStore.isOperationActive(RuntimeOperationKey.networkCreate) {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text(language.resolved == .zhHans ? "创建中" : "Creating")
                        }
                    } else {
                        Label(language.t(.createNetwork), systemImage: "plus.circle")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(runtimeStore.activeOperationKey != nil)
                .help(language.resolved == .zhHans ? "打开创建网络表单" : "Open the create network form")
                .sheet(isPresented: $showCreatePopover) {
                    createNetworkForm
                }
            }

            ResourceToolbar(searchText: $searchText, placeholder: language.t(.search)) {
                Text(language.itemCount(filteredNetworks.count))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if filteredNetworks.isEmpty {
                ResourceTable {
                    networkHeader
                } rows: {
                    EmptyStateView(title: language.t(.noNetworks), message: "macOS 26+ 支持创建用户定义容器网络。", systemImage: "network")
                        .padding(18)
                }
            } else {
                ResourceTable {
                    networkHeader
                } rows: {
                    ForEach(filteredNetworks) { network in
                        ResourceTableRow(
                            isSelected: selectedName == network.name || detailName == network.name,
                            onActivate: {
                                openNetworkDetail(network)
                            },
                            activationHelp: language.resolved == .zhHans ? "打开网络详情" : "Open network details"
                        ) {
                            let deleteKey = RuntimeOperationKey.networkDelete(network.name)
                            networkRowMainContent(network)

                            HStack(spacing: 8) {
                                RowActionButton(
                                    systemImage: "sidebar.right",
                                    help: language.resolved == .zhHans ? "打开网络详情抽屉" : "Open network details drawer"
                                ) {
                                    selectNetwork(network)
                                }
                                DestructiveRowActionButton(
                                    isLoading: runtimeStore.isOperationActive(deleteKey),
                                    isDisabled: runtimeStore.activeOperationKey != nil && !runtimeStore.isOperationActive(deleteKey),
                                    help: language.resolved == .zhHans ? "删除网络" : "Delete network"
                                ) {
                                    pendingDelete = network
                                }
                            }
                            .frame(width: 78, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    private func networkRowMainContent(_ network: NetworkSummary) -> some View {
        HStack(spacing: 12) {
            ResourceStatusDot(tint: .orange)

            Text(network.name)
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            StatusPill(title: network.configuration.mode, systemImage: "link", tint: .orange)
                .frame(width: 110, alignment: .leading)

            Text(network.ipv4ConfigurationText)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 170, alignment: .leading)

            Text(network.configuration.plugin)
                .lineLimit(1)
                .frame(width: 120, alignment: .leading)

            Text(network.createdText)
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .leading)
        }
    }

    private func openNetworkDetail(_ network: NetworkSummary) {
        selectedName = nil
        detailInitialTab = .overview
        detailName = network.name
    }

    private func selectNetwork(_ network: NetworkSummary) {
        selectedName = network.name
        drawerMode = .overview
        Task { await runtimeStore.inspectNetwork(network.name) }
    }

    private var createNetworkForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(language.t(.createNetwork))
                .font(.headline)
            TextField("network", text: $newNetworkName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
            TextField("192.168.100.0/24", text: $subnet)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
            TextField("fd00:100::/64", text: $subnetV6)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
            Toggle("Internal", isOn: $internalOnly)
                .toggleStyle(.switch)
            DisclosureGroup(
                isExpanded: $showAdvancedCreateOptions
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("container-network-vmnet", text: $plugin)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 320)
                    TextField("--label key=value, one per line", text: $labels, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                        .frame(width: 320)
                    TextField("--option key=value, one per line", text: $options, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                        .frame(width: 320)
                }
                .padding(.top, 8)
            } label: {
                Text(language.resolved == .zhHans ? "高级参数" : "Advanced")
                    .font(.callout.weight(.medium))
            }
            HStack {
                Spacer()
                Button("取消") {
                    showCreatePopover = false
                }
                .help(language.resolved == .zhHans ? "取消创建网络" : "Cancel creating network")
                Button(language.t(.create)) {
                    let createOptions = NetworkCreateOptions(
                        name: newNetworkName,
                        internalOnly: internalOnly,
                        plugin: plugin,
                        subnet: subnet,
                        subnetV6: subnetV6,
                        labels: lines(from: labels),
                        options: lines(from: options)
                    )
                    newNetworkName = ""
                    subnet = ""
                    subnetV6 = ""
                    internalOnly = false
                    plugin = ""
                    labels = ""
                    options = ""
                    showAdvancedCreateOptions = false
                    showCreatePopover = false
                    Task { await runtimeStore.createNetwork(options: createOptions) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(runtimeStore.activeOperationKey != nil)
                .help(language.resolved == .zhHans ? "创建网络" : "Create network")
            }
        }
        .padding(16)
    }

    private var networkHeader: some View {
        HStack(spacing: 12) {
            ResourceTableHeaderLabel(title: "", width: 20)
            ResourceTableHeaderLabel(title: language.t(.name))
            ResourceTableHeaderLabel(title: language.t(.mode), width: 110)
            ResourceTableHeaderLabel(title: language.t(.subnet), width: 170)
            ResourceTableHeaderLabel(title: language.t(.plugin), width: 120)
            ResourceTableHeaderLabel(title: language.t(.created), width: 140)
            ResourceTableHeaderLabel(title: language.t(.actions), width: 78, alignment: .trailing)
        }
    }

    private func lines(from text: String) -> [String] {
        text
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmed }
            .filter { !$0.isEmpty }
    }
}
