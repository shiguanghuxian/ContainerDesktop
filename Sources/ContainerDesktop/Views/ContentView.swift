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
    @State private var selectedQuickActionID: AppQuickAction.ID?
    @State private var pendingConfirmQuickAction: AppQuickAction?
    @State private var resourceRoute: AppResourceRoute?
    @State private var showOperationHistory = false
    @State private var observabilityResourceSnapshotRequestCounter = 0
    @State private var observabilityResourceSnapshotRequestID: Int?

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
            runtimeStore.bindOperationStore(operationStore)
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
        .onChange(of: resourceRoute) { _, route in
            guard let route else { return }
            switch route {
            case .container:
                selectSection(.containers)
            case .image, .imageTag, .imagePush, .imageTasks:
                selectSection(.images)
            case .volume:
                selectSection(.volumes)
            case .network:
                selectSection(.networks)
            case .composeProject, .composeTasks:
                selectSection(.compose)
            case .operationHistory:
                showOperationHistory = true
                resourceRoute = nil
            }
        }
        .onMoveCommand { direction in
            moveQuickActionSelection(direction)
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
                } onOpenDetails: {
                    showOperationHistory = true
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
                    actions: globalQuickActions,
                    selectedID: $selectedQuickActionID,
                    onSelect: applyQuickAction
                )
                .padding(.top, 56)
                .padding(.trailing, 118)
            }
        }
        .sheet(isPresented: $showOperationHistory) {
            OperationHistorySheet(operationStore: operationStore)
        }
        .confirmationDialog(
            pendingConfirmQuickAction?.title ?? "",
            isPresented: Binding(
                get: { pendingConfirmQuickAction != nil },
                set: { if !$0 { pendingConfirmQuickAction = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let action = pendingConfirmQuickAction {
                Button(language.resolved == .zhHans ? "执行" : "Run", role: .destructive) {
                    pendingConfirmQuickAction = nil
                    executeQuickAction(action)
                }
            }
            Button("取消", role: .cancel) {
                pendingConfirmQuickAction = nil
            }
        } message: {
            Text(pendingConfirmQuickAction?.subtitle ?? "")
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
                        systemConfigStore: systemConfigStore,
                        operationStore: operationStore,
                        onOpenResourceSnapshot: openObservabilityResourceSnapshot,
                        onOpenResourceRoute: { route in
                            resourceRoute = route
                        }
                    )
                }
            case .containers:
                ContainersView(
                    runtimeStore: runtimeStore,
                    composeStore: composeStore,
                    operationStore: operationStore,
                    statsHistoryStore: statsHistoryStore,
                    resourceRoute: $resourceRoute
                )
            case .machines:
                MachinesView(runtimeStore: runtimeStore)
            case .images:
                ImagesView(
                    runtimeStore: runtimeStore,
                    operationStore: operationStore,
                    resourceRoute: $resourceRoute
                )
            case .volumes:
                VolumesView(
                    runtimeStore: runtimeStore,
                    operationStore: operationStore,
                    resourceRoute: $resourceRoute
                )
            case .networks:
                NetworksView(
                    runtimeStore: runtimeStore,
                    resourceRoute: $resourceRoute
                )
            case .compose:
                ComposeView(
                    runtimeStore: runtimeStore,
                    composeStore: composeStore,
                    systemConfigStore: systemConfigStore,
                    operationStore: operationStore,
                    statsHistoryStore: statsHistoryStore,
                    resourceRoute: $resourceRoute
                )
            case .observability:
                ObservabilityView(
                    runtimeStore: runtimeStore,
                    composeStore: composeStore,
                    resourceSnapshotRequestID: $observabilityResourceSnapshotRequestID
                )
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
        guard let action = selectedQuickAction ?? globalQuickActions.first else { return }
        applyQuickAction(action)
    }

    private var allQuickActions: [AppQuickAction] {
        AppQuickActionBuilder.make(
            language: language,
            runtimeStore: runtimeStore,
            composeStore: composeStore,
            operationStore: operationStore
        )
    }

    private var globalQuickActions: [AppQuickAction] {
        let query = globalSearchText.trimmed
        guard !query.isEmpty else { return [] }
        return AppQuickActionSearch.filter(allQuickActions, query: query)
    }

    private var selectedQuickAction: AppQuickAction? {
        guard let selectedQuickActionID else { return nil }
        return globalQuickActions.first { $0.id == selectedQuickActionID }
    }

    private func applyQuickAction(_ action: AppQuickAction) {
        if action.kind == .confirmDestructive {
            pendingConfirmQuickAction = action
            return
        }
        executeQuickAction(action)
    }

    private func executeQuickAction(_ action: AppQuickAction) {
        switch action.target {
        case .navigate(let target):
            navigate(to: target)
        case .refreshAll:
            Task { await runtimeStore.refreshAll() }
        case .startSystem:
            Task { await runtimeStore.startSystem() }
        case .stopSystem:
            Task { await runtimeStore.stopSystem() }
        case .openSettings:
            ContainerDesktopWindowRouter.openSettings()
        case .openDockerTerminal:
            ContainerDesktopWindowRouter.openDockerCompatibilityTerminal()
        case .startContainer(let id):
            Task { await runtimeStore.startContainer(id) }
        case .stopContainer(let id):
            Task { await runtimeStore.stopContainer(id) }
        case .restartContainer(let id):
            Task { await runtimeStore.restartContainer(id) }
        case .runContainerImage(let reference):
            Task {
                await runtimeStore.runContainer(options: ContainerRunOptions(image: reference))
            }
        case .runTemplate(let id):
            guard let template = DeveloperRunTemplate.template(id: id) else { break }
            Task {
                await runtimeStore.runContainer(options: template.options())
            }
        case .pullImage(let reference):
            pullImageFromPalette(reference)
        case .tagImage(let reference):
            navigate(to: .resource(.imageTag(reference: reference)))
        case .pushImage(let reference):
            navigate(to: .resource(.imagePush(reference: reference)))
        case .compose(let action, let projectID, let serviceName):
            runComposeQuickAction(action, projectID: projectID, serviceName: serviceName)
        case .copyText(let value):
            copyToPasteboard(value)
        case .openURL(let value):
            if let url = URL(string: value), !value.isEmpty {
                NSWorkspace.shared.open(url)
            }
        case .openOperationHistory:
            showOperationHistory = true
        case .confirmDestructive:
            break
        }
        globalSearchText = ""
        selectedQuickActionID = nil
    }

    private func navigate(to target: AppNavigationTarget) {
        switch target {
        case .section(let section):
            selectSection(section)
        case .resource(let route):
            switch route {
            case .container:
                selectSection(.containers)
            case .image, .imageTag, .imagePush, .imageTasks:
                selectSection(.images)
            case .volume:
                selectSection(.volumes)
            case .network:
                selectSection(.networks)
            case .composeProject, .composeTasks:
                selectSection(.compose)
            case .operationHistory:
                showOperationHistory = true
                return
            }
            resourceRoute = route
        }
    }

    private func runComposeQuickAction(_ action: AppComposeQuickActionKind, projectID: ComposeProject.ID, serviceName: String?) {
        guard let project = composeStore.projects.first(where: { $0.id == projectID }) else { return }
        let services = serviceName.map { [$0] } ?? []
        let options = ComposeOperationOptions(services: services)
        let id = operationStore.start(
            domain: .compose,
            title: action.title(language: language),
            target: services.isEmpty ? project.name : "\(project.name) / \(services.joined(separator: ", "))",
            commandPreview: action.commandPreview(composePath: project.path, options: options)
        )
        Task {
            switch action {
            case .build:
                await composeStore.build(project, options: options)
            case .up:
                await composeStore.up(project, options: options)
            case .down:
                await composeStore.down(project, options: options)
            case .rebuild:
                await composeStore.rebuild(project, options: options)
            }
            await runtimeStore.refreshAll()
            operationStore.finish(
                id: id,
                status: composeStore.errorMessage == nil ? .succeeded : .failed,
                output: composeStore.lastOutput
            )
        }
    }

    private func pullImageFromPalette(_ reference: String) {
        let id = operationStore.start(
            domain: .image,
            title: language.resolved == .zhHans ? "拉取镜像" : "Pull image",
            target: reference,
            commandPreview: AppOperationCommandPreview.make(executable: "container", arguments: ["image", "pull", reference])
        )
        Task {
            await runtimeStore.pullImage(reference)
            operationStore.finish(
                id: id,
                status: runtimeStore.imageOperationStatusIsError ? .failed : .succeeded,
                output: runtimeStore.imageOperationStatusMessage ?? ""
            )
        }
    }

    private func moveQuickActionSelection(_ direction: MoveCommandDirection) {
        guard !globalSearchText.trimmed.isEmpty, !globalQuickActions.isEmpty else { return }
        let ids = globalQuickActions.map(\.id)
        let currentIndex = selectedQuickActionID.flatMap { ids.firstIndex(of: $0) } ?? 0
        let nextIndex: Int
        switch direction {
        case .up:
            nextIndex = max(currentIndex - 1, 0)
        case .down:
            nextIndex = min(currentIndex + 1, ids.count - 1)
        default:
            return
        }
        selectedQuickActionID = ids[nextIndex]
    }

    private func selectSection(_ section: AppSection) {
        selectedSectionRaw = section.rawValue
        ContainerDesktopMainMenuController.shared.updateSelectedSection(section)
    }

    private func openObservabilityResourceSnapshot() {
        observabilityResourceSnapshotRequestCounter += 1
        observabilityResourceSnapshotRequestID = observabilityResourceSnapshotRequestCounter
        selectSection(.observability)
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}

private struct OperationHistorySheet: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    var operationStore: AppOperationStore

    var body: some View {
        VStack(spacing: 0) {
            DrawerHeader(
                title: language.resolved == .zhHans ? "操作历史" : "Operation History",
                subtitle: language.resolved == .zhHans ? "最近命令、输出和诊断摘要" : "Recent commands, output, and diagnostics",
                systemImage: "clock.arrow.circlepath",
                onClose: { dismiss() }
            )
            Divider()
            ScrollView {
                OperationHistoryPanel(
                    store: operationStore,
                    domains: Set(AppOperationDomain.allCases),
                    title: language.resolved == .zhHans ? "操作历史" : "Operation History",
                    limit: 40
                )
                .padding(16)
            }
            .thinScrollBars()
            .frame(maxHeight: .infinity)
        }
        .frame(width: 720, height: 620)
    }
}
