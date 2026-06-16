import SwiftUI

struct NetworksView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var runtimeStore: RuntimeStore
    @State private var searchText = ""
    @State private var newNetworkName = ""
    @State private var subnet = ""
    @State private var subnetV6 = ""
    @State private var internalOnly = false
    @State private var showCreatePopover = false
    @State private var selectedName: String?
    @State private var pendingDelete: NetworkSummary?
    @State private var drawerMode: DetailDrawerMode = .overview

    private var filteredNetworks: [NetworkSummary] {
        let query = searchText.trimmed.lowercased()
        guard !query.isEmpty else { return runtimeStore.networks }
        return runtimeStore.networks.filter {
            $0.name.lowercased().contains(query) || $0.subnetText.lowercased().contains(query)
        }
    }

    private var selectedNetwork: NetworkSummary? {
        guard let selectedName else { return nil }
        return runtimeStore.networks.first { $0.name == selectedName }
    }

    var body: some View {
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
                    NetworkDetailOverview(network: selectedNetwork)
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
                        ResourceTableRow(isSelected: selectedName == network.name) {
                            let deleteKey = RuntimeOperationKey.networkDelete(network.name)
                            ResourceStatusDot(tint: .orange)

                            Text(network.name)
                                .font(.callout.weight(.medium))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            StatusPill(title: network.configuration.mode, systemImage: "link", tint: .orange)
                                .frame(width: 110, alignment: .leading)

                            Text(network.subnetText)
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
            HStack {
                Spacer()
                Button("取消") {
                    showCreatePopover = false
                }
                .help(language.resolved == .zhHans ? "取消创建网络" : "Cancel creating network")
                Button(language.t(.create)) {
                    let name = newNetworkName
                    let ipv4 = subnet
                    let ipv6 = subnetV6
                    let internalFlag = internalOnly
                    newNetworkName = ""
                    subnet = ""
                    subnetV6 = ""
                    internalOnly = false
                    showCreatePopover = false
                    Task { await runtimeStore.createNetwork(name: name, subnet: ipv4, subnetV6: ipv6, internalOnly: internalFlag) }
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
}

private struct NetworkDetailOverview: View {
    @Environment(\.appLanguage) private var language
    var network: NetworkSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            DetailSection(title: language.resolved == .zhHans ? "网络" : "Network") {
                DetailInfoCard {
                    DetailInfoRow(title: language.t(.name), value: network.name)
                    DetailInfoRow(title: language.t(.mode), value: network.configuration.mode)
                    DetailInfoRow(title: language.t(.plugin), value: network.configuration.plugin)
                    DetailInfoRow(title: language.t(.subnet), value: network.subnetText, monospaced: true)
                    DetailInfoRow(title: "IPv6", value: network.configuration.ipv6Subnet ?? "—", monospaced: true)
                    DetailInfoRow(title: language.t(.created), value: network.createdText)
                }
            }

            DetailSection(title: "Metadata") {
                DetailInfoCard {
                    if network.configuration.labels.isEmpty && network.configuration.options.isEmpty {
                        Text(language.resolved == .zhHans ? "没有标签或插件选项。" : "No labels or plugin options.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(network.configuration.labels.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            DetailInfoRow(title: key, value: value)
                        }
                        ForEach(network.configuration.options.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            DetailInfoRow(title: key, value: value)
                        }
                    }
                }
            }
        }
    }
}
