import SwiftUI

struct ContainersView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var runtimeStore: RuntimeStore
    @State private var searchText = ""
    @State private var onlyRunning = false
    @State private var showRunPopover = false
    @State private var newContainerName = ""
    @State private var newContainerImage = "alpine:latest"
    @State private var newContainerCommand = "sleep 3600"
    @State private var selectedID: String?
    @State private var pendingDelete: ContainerSummary?
    @State private var drawerMode: DetailDrawerMode = .overview

    private var filteredContainers: [ContainerSummary] {
        let query = searchText.trimmed.lowercased()
        let base = onlyRunning ? runtimeStore.containers.filter { $0.state == "running" } : runtimeStore.containers
        guard !query.isEmpty else { return base }
        return base.filter {
            $0.id.lowercased().contains(query)
                || $0.imageName.lowercased().contains(query)
                || $0.state.lowercased().contains(query)
        }
    }

    private var selectedContainer: ContainerSummary? {
        guard let selectedID else { return nil }
        return runtimeStore.containers.first { $0.id == selectedID }
    }

    var body: some View {
        DrawerPageLayout(isDrawerPresented: selectedContainer != nil) {
            pageContent
        } drawer: {
            if let selectedContainer {
                DetailDrawer(
                    mode: $drawerMode,
                    title: selectedContainer.id,
                    subtitle: "container inspect",
                    systemImage: "shippingbox",
                    rawText: runtimeStore.selectedInspectorText,
                    onClose: {
                        selectedID = nil
                    }
                ) {
                    ContainerDetailOverview(
                        container: selectedContainer,
                        stats: runtimeStore.selectedStats.first { $0.id == selectedContainer.id },
                        logs: runtimeStore.selectedLogs
                    )
                }
            }
        }
        .alert("删除容器？", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            if let container = pendingDelete {
                Button("删除", role: .destructive) {
                    pendingDelete = nil
                    Task { await runtimeStore.deleteContainer(container.id) }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将删除容器 \(pendingDelete?.id ?? "所选容器")。运行中的容器需要先停止。")
        }
    }

    private var pageContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(
                title: language.t(.containers),
                subtitle: language.t(.containersSubtitle),
                systemImage: "shippingbox"
            ) {
                HStack(spacing: 8) {
                    Button {
                        showRunPopover = true
                    } label: {
                        Label(language.resolved == .zhHans ? "运行容器" : "Run Container", systemImage: "play.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .popover(isPresented: $showRunPopover, arrowEdge: .bottom) {
                        runContainerForm
                    }

                    Button {
                        Task { await runtimeStore.refreshAll() }
                    } label: {
                        Label(language.t(.refresh), systemImage: "arrow.clockwise")
                    }
                }
            }

            ResourceToolbar(searchText: $searchText, placeholder: language.t(.search)) {
                Toggle(language.t(.onlyRunning), isOn: $onlyRunning)
                    .toggleStyle(.switch)
                Text(language.itemCount(filteredContainers.count))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if filteredContainers.isEmpty {
                ResourceTable {
                    containerHeader
                } rows: {
                    EmptyStateView(title: language.t(.noContainers), message: "Start container system, run an image, or bring up a Compose project.", systemImage: "shippingbox")
                        .padding(18)
                }
            } else {
                ResourceTable {
                    containerHeader
                } rows: {
                    ForEach(filteredContainers) { container in
                        ResourceTableRow(isSelected: selectedID == container.id) {
                            ResourceStatusDot(tint: container.state == "running" ? CDTheme.lime : .secondary)

                            Text(container.id)
                                .font(.callout.weight(.medium))
                                .lineLimit(1)
                                .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)

                            Text(container.imageName)
                                .lineLimit(1)
                                .frame(width: 180, alignment: .leading)

                            Text(container.primaryIP)
                                .font(.callout.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                                .frame(width: 118, alignment: .leading)

                            Text(container.state)
                                .lineLimit(1)
                                .frame(width: 76, alignment: .leading)

                            HStack(spacing: 10) {
                                RowActionButton(systemImage: container.state == "running" ? "stop.fill" : "play.fill") {
                                    selectedID = container.id
                                    Task {
                                        if container.state == "running" {
                                            await runtimeStore.stopContainer(container.id)
                                        } else {
                                            await runtimeStore.startContainer(container.id)
                                        }
                                    }
                                }
                                RowActionButton(systemImage: "sidebar.right") {
                                    selectContainer(container)
                                }
                                DestructiveRowActionButton {
                                    pendingDelete = container
                                }
                            }
                            .frame(width: 108, alignment: .trailing)
                        }
                        .onTapGesture {
                            selectContainer(container)
                        }
                    }
                }
            }
        }
    }

    private func selectContainer(_ container: ContainerSummary) {
        selectedID = container.id
        drawerMode = .overview
        Task {
            await runtimeStore.inspectContainer(container.id)
            await runtimeStore.loadContainerLogs(container.id)
            await runtimeStore.loadContainerStats(container.id)
        }
    }

    private var containerHeader: some View {
        HStack(spacing: 12) {
            ResourceTableHeaderLabel(title: "", width: 20)
            ResourceTableHeaderLabel(title: language.t(.name))
            ResourceTableHeaderLabel(title: language.t(.image), width: 180)
            ResourceTableHeaderLabel(title: "IP", width: 118)
            ResourceTableHeaderLabel(title: language.t(.status), width: 76)
            ResourceTableHeaderLabel(title: language.t(.actions), width: 108, alignment: .trailing)
        }
    }

    private var runContainerForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(language.resolved == .zhHans ? "运行新容器" : "Run New Container")
                .font(.headline)
            TextField(language.t(.name), text: $newContainerName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 320)
            TextField(language.t(.image), text: $newContainerImage)
                .textFieldStyle(.roundedBorder)
                .frame(width: 320)
            TextField("command", text: $newContainerCommand)
                .textFieldStyle(.roundedBorder)
                .frame(width: 320)
            HStack {
                Spacer()
                Button("取消") {
                    showRunPopover = false
                }
                Button(language.resolved == .zhHans ? "运行" : "Run") {
                    let name = newContainerName
                    let image = newContainerImage
                    let command = newContainerCommand
                    showRunPopover = false
                    Task {
                        await runtimeStore.runContainer(name: name, image: image, commandText: command)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
    }
}

private struct ContainerDetailOverview: View {
    @Environment(\.appLanguage) private var language
    var container: ContainerSummary
    var stats: ContainerStatsSnapshot?
    var logs: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            DetailSection(title: language.resolved == .zhHans ? "容器" : "Container") {
                DetailInfoCard {
                    DetailInfoRow(title: language.t(.status), value: container.state)
                    DetailInfoRow(title: language.t(.image), value: container.imageName)
                    DetailInfoRow(title: "IP", value: container.primaryIP, monospaced: true)
                    DetailInfoRow(title: "Platform", value: container.platformName)
                    DetailInfoRow(title: "Started", value: container.startedText)
                }
            }

            DetailSection(title: language.resolved == .zhHans ? "资源" : "Resources") {
                DetailInfoCard {
                    DetailInfoRow(title: "CPUs", value: "\(container.cpuCount)")
                    DetailInfoRow(title: "Memory", value: container.memoryDisplay)
                    if let stats {
                        DetailInfoRow(title: "Used", value: "\(stats.memoryUsageDisplay) / \(stats.memoryLimitDisplay)")
                        DetailInfoRow(title: "Network", value: stats.networkDisplay)
                        DetailInfoRow(title: "Block IO", value: stats.blockIODisplay)
                        DetailInfoRow(title: "Processes", value: "\(stats.numProcesses)")
                    } else {
                        Text(language.resolved == .zhHans ? "Stats 加载中或暂无数据。" : "Stats are loading or unavailable.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            DetailSection(title: language.t(.logs)) {
                TerminalBlock(text: logs.isEmpty ? (language.resolved == .zhHans ? "暂无日志。" : "No logs.") : logs, minHeight: 180)
            }
        }
    }
}
