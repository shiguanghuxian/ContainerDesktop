import AppKit
import SwiftUI

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var runtimeStore: RuntimeStore
    @Bindable var composeStore: ComposeProjectStore
    @Bindable var systemConfigStore: SystemConfigStore
    @Bindable var operationStore: AppOperationStore
    @Bindable var appUpdateStore: AppUpdateStore
    @Bindable var statsHistoryStore: ContainerStatsHistoryStore

    @AppStorage("containerdesktop.selected.section") private var selectedSectionRaw = AppSection.dashboard.rawValue
    @AppStorage("containerdesktop.sidebar.collapsed") private var isSidebarCollapsed = false
    @State private var globalSearchText = ""

    private var selectedSection: AppSection {
        get { AppSection(rawValue: selectedSectionRaw) ?? .dashboard }
        set { selectSection(newValue) }
    }

    private var selectedSectionBinding: Binding<AppSection> {
        Binding(
            get: { selectedSection },
            set: { selectSection($0) }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                searchText: $globalSearchText,
                isSidebarCollapsed: $isSidebarCollapsed,
                onSearchSubmit: handleGlobalSearchSubmit,
                runtimeStore: runtimeStore,
                composeStore: composeStore,
                systemConfigStore: systemConfigStore
            )

            HStack(spacing: 0) {
                SidebarView(
                    selection: selectedSectionBinding,
                    runtimeStore: runtimeStore,
                    composeStore: composeStore,
                    isCollapsed: isSidebarCollapsed
                )

                Divider()

                detailView(for: selectedSection)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            AppStatusBar(runtimeStore: runtimeStore, operationStore: operationStore)
        }
        .ignoresSafeArea(.container, edges: [.top])
        .task {
            operationStore.load()
            statsHistoryStore.load()
            await runtimeStore.bootstrap()
            await composeStore.load()
            await composeStore.refreshVersion()
            await systemConfigStore.load()
        }
        .task(id: runtimeStore.isReady) {
            statsHistoryStore.load()
            if runtimeStore.isReady {
                statsHistoryStore.startMonitoring(interval: 10)
            } else {
                statsHistoryStore.stopMonitoring()
            }
        }
        .onAppear {
            ContainerDesktopMainMenuController.shared.updateSelectedSection(selectedSection)
        }
        .onChange(of: selectedSectionRaw) { _, newValue in
            let section = AppSection(rawValue: newValue) ?? .dashboard
            ContainerDesktopMainMenuController.shared.updateSelectedSection(section)
        }
        .alert("错误", isPresented: Binding(
            get: { runtimeStore.errorMessage != nil },
            set: { if !$0 { runtimeStore.errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(runtimeStore.errorMessage ?? "Unknown error")
        }
        .overlay(alignment: .bottom) {
            if let feedback = runtimeStore.operationFeedback {
                OperationToast(feedback: feedback) {
                    runtimeStore.dismissOperationFeedback()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 46)
                .transition(
                    .move(edge: .bottom)
                        .combined(with: .opacity)
                        .combined(with: .scale(scale: 0.96, anchor: .bottom))
                )
                .zIndex(10)
            }
        }
        .animation(.snappy(duration: 0.22), value: runtimeStore.operationFeedback?.id)
        .overlay(alignment: .topTrailing) {
            let query = globalSearchText.trimmed
            if !query.isEmpty {
                GlobalSearchPanel(
                    query: query,
                    results: globalSearchResults,
                    onSelect: applyGlobalSearchResult
                )
                .padding(.top, 56)
                .padding(.trailing, 118)
            }
        }
        .tint(CDTheme.dockerBlue)
    }

    @ViewBuilder
    private func detailView(for section: AppSection) -> some View {
        ZStack {
            TechBackdrop()

            switch section {
            case .dashboard:
                PageScrollContainer {
                    DashboardView(
                        runtimeStore: runtimeStore,
                        composeStore: composeStore,
                        systemConfigStore: systemConfigStore
                    )
                }
            case .containers:
                ContainersView(runtimeStore: runtimeStore, statsHistoryStore: statsHistoryStore)
            case .machines:
                MachinesView(runtimeStore: runtimeStore)
            case .images:
                ImagesView(runtimeStore: runtimeStore, operationStore: operationStore)
            case .volumes:
                VolumesView(runtimeStore: runtimeStore)
            case .networks:
                NetworksView(runtimeStore: runtimeStore)
            case .compose:
                ComposeView(
                    runtimeStore: runtimeStore,
                    composeStore: composeStore,
                    systemConfigStore: systemConfigStore,
                    operationStore: operationStore,
                    statsHistoryStore: statsHistoryStore
                )
            case .observability:
                ObservabilityView(runtimeStore: runtimeStore, composeStore: composeStore)
            case .registries:
                RegistriesView(runtimeStore: runtimeStore)
            case .commandConverter:
                PageScrollContainer {
                    DockerCommandConverterView()
                }
            case .system:
                SystemView(runtimeStore: runtimeStore, systemConfigStore: systemConfigStore)
            case .help:
                PageScrollContainer {
                    HelpView()
                }
            case .about:
                PageScrollContainer {
                    AboutView(runtimeStore: runtimeStore, composeStore: composeStore, appUpdateStore: appUpdateStore)
                }
            }
        }
    }

    private func handleGlobalSearchSubmit() {
        guard let first = globalSearchResults.first else { return }
        applyGlobalSearchResult(first)
    }

    private var globalSearchResults: [GlobalSearchResult] {
        let query = globalSearchText.trimmed.lowercased()
        guard !query.isEmpty else { return [] }

        var results: [GlobalSearchResult] = []

        if matches(query, ["刷新", "refresh", "reload"]) {
            results.append(.init(
                id: "command.refresh",
                title: language.t(.refresh),
                subtitle: language.resolved == .zhHans ? "刷新所有 container 资源" : "Refresh all container resources",
                systemImage: "arrow.clockwise",
                tint: CDTheme.dockerBlue,
                target: .refresh
            ))
        }
        if matches(query, ["启动", "start", "system"]) {
            results.append(.init(
                id: "command.start-system",
                title: language.t(.startSystem),
                subtitle: "container system start",
                systemImage: "play.circle",
                tint: CDTheme.lime,
                target: .startSystem
            ))
        }
        if matches(query, ["停止", "stop", "system"]) {
            results.append(.init(
                id: "command.stop-system",
                title: language.t(.stopSystem),
                subtitle: "container system stop",
                systemImage: "stop.circle",
                tint: CDTheme.ember,
                target: .stopSystem
            ))
        }
        if matches(query, ["设置", "settings", "config"]) {
            results.append(.init(
                id: "command.settings",
                title: language.t(.settings),
                subtitle: language.t(.engineConfig),
                systemImage: "gearshape",
                tint: CDTheme.dockerBlue,
                target: .settings
            ))
        }

        results.append(contentsOf: sectionMatches(query: query))
        results.append(contentsOf: resourceMatches(query: query))

        return Array(results.prefix(8))
    }

    private func applyGlobalSearchResult(_ result: GlobalSearchResult) {
        switch result.target {
        case .section(let section):
            selectSection(section)
        case .refresh:
            Task { await runtimeStore.refreshAll() }
        case .startSystem:
            Task { await runtimeStore.startSystem() }
        case .stopSystem:
            Task { await runtimeStore.stopSystem() }
        case .settings:
            ContainerDesktopWindowRouter.openSettings()
        }
        globalSearchText = ""
    }

    private func selectSection(_ section: AppSection) {
        selectedSectionRaw = section.rawValue
        ContainerDesktopMainMenuController.shared.updateSelectedSection(section)
    }

    private func sectionMatches(query: String) -> [GlobalSearchResult] {
        AppSection.allCases.compactMap { section in
            let haystack = [
                section.rawValue,
                section.title(language: language),
                section.subtitle(language: language),
            ].joined(separator: " ").lowercased()
            guard haystack.contains(query) else { return nil }
            return GlobalSearchResult(
                id: "section.\(section.rawValue)",
                title: section.title(language: language),
                subtitle: section.subtitle(language: language),
                systemImage: section.symbolName,
                tint: CDTheme.dockerBlue,
                target: .section(section)
            )
        }
    }

    private func resourceMatches(query: String) -> [GlobalSearchResult] {
        var results: [GlobalSearchResult] = []
        for container in runtimeStore.containers where contains(query, in: [container.id, container.imageName, container.state]) {
            results.append(.init(id: "container.\(container.id)", title: container.id, subtitle: container.imageName, systemImage: "shippingbox", tint: container.state == "running" ? CDTheme.lime : .secondary, target: .section(.containers)))
        }
        for machine in runtimeStore.machines where contains(query, in: [machine.id, machine.statusText, machine.ipAddressText]) {
            results.append(.init(id: "machine.\(machine.id)", title: machine.id, subtitle: machine.statusText, systemImage: "desktopcomputer", tint: machine.isRunning ? CDTheme.lime : .secondary, target: .section(.machines)))
        }
        for image in runtimeStore.images where contains(query, in: [image.reference, image.tag, image.digest]) {
            results.append(.init(id: "image.\(image.reference)", title: image.reference, subtitle: image.sizeDisplay, systemImage: "photo.stack", tint: CDTheme.violet, target: .section(.images)))
        }
        for volume in runtimeStore.volumes where contains(query, in: [volume.name, volume.source, volume.driver]) {
            results.append(.init(id: "volume.\(volume.name)", title: volume.name, subtitle: volume.sizeDisplay, systemImage: "externaldrive", tint: CDTheme.lime, target: .section(.volumes)))
        }
        for network in runtimeStore.networks where contains(query, in: [network.name, network.subnetText]) {
            results.append(.init(id: "network.\(network.name)", title: network.name, subtitle: network.subnetText, systemImage: "network", tint: CDTheme.ember, target: .section(.networks)))
        }
        for project in composeStore.projects where contains(query, in: [project.name, project.path.path]) {
            results.append(.init(id: "compose.\(project.id)", title: project.name, subtitle: "\(project.services.count) services", systemImage: "square.stack.3d.up", tint: CDTheme.dockerBlue, target: .section(.compose)))
        }
        return results
    }

    private func matches(_ query: String, _ keywords: [String]) -> Bool {
        keywords.contains { keyword in
            keyword.lowercased().contains(query) || query.contains(keyword.lowercased())
        }
    }

    private func contains(_ query: String, in values: [String]) -> Bool {
        values.contains { $0.lowercased().contains(query) }
    }
}
