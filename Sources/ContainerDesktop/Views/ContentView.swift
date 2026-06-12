import SwiftUI

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var runtimeStore: RuntimeStore
    @Bindable var composeStore: ComposeProjectStore
    @Bindable var systemConfigStore: SystemConfigStore

    @AppStorage("containerdesktop.selected.section") private var selectedSectionRaw = AppSection.dashboard.rawValue
    @AppStorage("containerdesktop.sidebar.collapsed") private var isSidebarCollapsed = false
    @State private var globalSearchText = ""

    private var selectedSection: AppSection {
        get { AppSection(rawValue: selectedSectionRaw) ?? .dashboard }
        set { selectedSectionRaw = newValue.rawValue }
    }

    private var selectedSectionBinding: Binding<AppSection> {
        Binding(
            get: { selectedSection },
            set: { selectedSectionRaw = $0.rawValue }
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
            }

            AppStatusBar(runtimeStore: runtimeStore)
        }
        .ignoresSafeArea(.container, edges: [.top])
        .task {
            await runtimeStore.bootstrap()
            await composeStore.load()
            await systemConfigStore.load()
        }
        .alert("错误", isPresented: Binding(
            get: { runtimeStore.errorMessage != nil },
            set: { if !$0 { runtimeStore.errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(runtimeStore.errorMessage ?? "Unknown error")
        }
        .overlay(alignment: .bottomLeading) {
            if let busyMessage = runtimeStore.busyMessage {
                StatusPill(title: busyMessage, systemImage: "hourglass", tint: .blue)
                    .padding()
            }
        }
        .tint(CDTheme.dockerBlue)
    }

    @ViewBuilder
    private func detailView(for section: AppSection) -> some View {
        ZStack {
            TechBackdrop().ignoresSafeArea()

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
                ContainersView(runtimeStore: runtimeStore)
            case .images:
                ImagesView(runtimeStore: runtimeStore)
            case .volumes:
                VolumesView(runtimeStore: runtimeStore)
            case .networks:
                NetworksView(runtimeStore: runtimeStore)
            case .compose:
                ComposeView(runtimeStore: runtimeStore, composeStore: composeStore)
            case .registries:
                PageScrollContainer {
                    RegistriesView(runtimeStore: runtimeStore)
                }
            case .system:
                SystemView(runtimeStore: runtimeStore, systemConfigStore: systemConfigStore)
            }
        }
    }

    private func handleGlobalSearchSubmit() {
        let query = globalSearchText.trimmed.lowercased()
        guard !query.isEmpty else { return }
        if let section = AppSection.allCases.first(where: {
            $0.title(language: language).lowercased().contains(query)
                || $0.subtitle(language: language).lowercased().contains(query)
                || $0.rawValue.lowercased().contains(query)
        }) {
            selectedSectionRaw = section.rawValue
            globalSearchText = ""
        }
    }
}
